import Foundation

public struct TimeZoneSelection: Equatable, Sendable {
    public let identifier: String
    /// Nil for existing/imported city zones; explicit choices save a fixed
    /// offset identifier plus their chosen label (PST must never become PDT).
    public let abbreviation: String?

    public init(identifier: String, abbreviation: String? = nil) {
        self.identifier = identifier
        self.abbreviation = abbreviation
    }

    public var timeZone: TimeZone? { TimeZone(identifier: identifier) }
    public var name: String {
        abbreviation ?? timeZone?.localizedName(for: .generic, locale: .current) ?? identifier
    }
    public func offsetLabel(at date: Date) -> String {
        guard let timeZone else { return identifier }
        let offset = TimeZoneCatalog.offsetLabel(seconds: timeZone.secondsFromGMT(for: date))
        return abbreviation == nil ? "\(timeZone.abbreviation(for: date) ?? identifier) · \(offset)" : "\(offset) · Fixed offset"
    }
}

/// One explicit abbreviation/offset, with every associated city linked to it.
public struct TimeZoneOption: Identifiable, Sendable {
    public let name: String
    public let abbreviation: String
    public let secondsFromGMT: Int
    public let identifiers: [String]
    public let selection: TimeZoneSelection
    fileprivate let searchNames: [String]
    public var id: String { "\(abbreviation)|\(secondsFromGMT)" }
    public var offsetLabel: String { TimeZoneCatalog.offsetLabel(seconds: secondsFromGMT) }

    public func isSelected(_ selection: TimeZoneSelection, at date: Date) -> Bool {
        if selection.abbreviation != nil { return self.selection == selection }
        return identifiers.contains(selection.identifier)
            && selection.timeZone?.secondsFromGMT(for: date) == secondsFromGMT
            && selection.timeZone?.abbreviation(for: date) == abbreviation
    }

    public func citySummary(matching query: String = "", limit: Int = 3) -> String {
        let ordered = identifiers.sorted {
            let lhs = !query.isEmpty && TimeZoneCatalog.matches(query, names: [$0])
            let rhs = !query.isEmpty && TimeZoneCatalog.matches(query, names: [$1])
            return lhs == rhs ? $0 < $1 : lhs
        }
        var seen = Set<String>()
        let cities = ordered.map { $0.split(separator: "/").last.map(String.init) ?? $0 }
            .map { $0.replacingOccurrences(of: "_", with: " ") }
            .filter { seen.insert($0).inserted }
        let count = max(1, limit)
        let shown = cities.prefix(count).joined(separator: ", ")
        return cities.count > count ? "\(shown) +\(cities.count - count)" : shown
    }
}

public enum TimeZoneCatalog {
    private struct Key: Hashable {
        let abbreviation: String
        let offset: Int
    }

    public static func options(at date: Date, including selected: TimeZoneSelection? = nil,
                               identifiers: [String] = TimeZone.knownTimeZoneIdentifiers,
                               locale: Locale = .current) -> [TimeZoneOption] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let year = calendar.dateInterval(of: .year, for: date) else { return [] }
        var members: [Key: Set<String>] = [:]
        var names: [Key: Set<String>] = [:]
        var genericNames: [Key: Set<String>] = [:]
        let extraCity = selected.flatMap { $0.abbreviation == nil ? $0.identifier : nil }
        let identifiers = Set(identifiers + (extraCity.map { [$0] } ?? []))
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "zzzz"
        for identifier in identifiers.sorted() {
            guard let zone = TimeZone(identifier: identifier) else { continue }
            formatter.timeZone = zone
            var samples = [year.start, date]
            var cursor = year.start
            while let next = zone.nextDaylightSavingTimeTransition(after: cursor), next < year.end, next > cursor {
                samples.append(next.addingTimeInterval(1))
                cursor = next.addingTimeInterval(1)
            }
            for sample in samples {
                let offset = zone.secondsFromGMT(for: sample)
                guard let abbreviation = zone.abbreviation(for: sample), TimeZone(secondsFromGMT: offset) != nil else { continue }
                let key = Key(abbreviation: abbreviation, offset: offset)
                members[key, default: []].insert(identifier)
                names[key, default: []].insert(formatter.string(from: sample))
                genericNames[key, default: []].insert(zone.localizedName(for: .generic, locale: locale) ?? identifier)
            }
        }
        // Keep a previously saved explicit offset available even if the system
        // database no longer associates it with a city in the deadline year.
        if let selected, let abbreviation = selected.abbreviation, let zone = selected.timeZone {
            let key = Key(abbreviation: abbreviation, offset: zone.secondsFromGMT(for: date))
            if members[key] == nil {
                members[key] = [selected.identifier]
                names[key] = [abbreviation]
            }
        }
        return members.compactMap { key, identifiers -> TimeZoneOption? in
            guard let zone = TimeZone(secondsFromGMT: key.offset) else { return nil }
            let titles = names[key] ?? []
            let title = titles.count == 1 ? titles.first! : key.abbreviation
            let sign = key.offset < 0 ? "-" : "+"
            let hours = abs(key.offset) / 3_600
            let minutes = abs(key.offset) % 3_600 / 60
            let offsets = [offsetLabel(seconds: key.offset),
                           String(format: "UTC%@%d:%02d", sign, hours, minutes),
                           String(format: "GMT%@%d:%02d", sign, hours, minutes)]
            return TimeZoneOption(name: title, abbreviation: key.abbreviation, secondsFromGMT: key.offset,
                                  identifiers: identifiers.sorted(),
                                  selection: TimeZoneSelection(identifier: zone.identifier, abbreviation: key.abbreviation),
                                  searchNames: Array(titles.union(genericNames[key] ?? [])) + offsets)
        }.sorted { $0.name == $1.name ? $0.id < $1.id : $0.name < $1.name }
    }

    public static func search(_ query: String, in options: [TimeZoneOption]) -> [TimeZoneOption] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // An explicit abbreviation wins over all city/name aliases. In
        // particular, an identifier like PST8PDT must not leak PDT into PST.
        let exact = options.filter { $0.abbreviation.caseInsensitiveCompare(query) == .orderedSame }
        if !exact.isEmpty { return exact }
        return options.filter { matches(query, names: [$0.abbreviation] + $0.searchNames + $0.identifiers) }
    }

    fileprivate static func matches(_ query: String, names: [String]) -> Bool {
        func words(_ text: String) -> [String] {
            text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .replacingOccurrences(of: "−", with: "-")
                .split(whereSeparator: { $0.isWhitespace || $0 == "/" || $0 == "_" }).map(String.init)
        }
        let terms = words(query)
        return names.contains { name in
            let tokens = words(name)
            return terms.allSatisfy { term in tokens.contains { $0.hasPrefix(term) } }
        }
    }

    public static func offsetLabel(seconds: Int) -> String {
        String(format: "UTC%@%02d:%02d", seconds < 0 ? "-" : "+", abs(seconds) / 3_600, abs(seconds) % 3_600 / 60)
    }
}
