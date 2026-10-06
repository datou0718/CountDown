import Foundation

/// A named time zone with all of its city identifiers available as search aliases.
/// Grouping is for presentation only; events continue to save an IANA identifier.
public struct TimeZoneGroup: Identifiable, Sendable {
    public let name: String
    public let identifiers: [String]
    private let searchNames: [String]
    public var id: String { identifiers[0] }

    fileprivate init(name: String, identifiers: [String], searchNames: [String]) {
        self.name = name
        self.identifiers = identifiers.sorted()
        self.searchNames = searchNames
    }

    public func contains(_ identifier: String) -> Bool { identifiers.contains(identifier) }

    public func matches(_ query: String) -> Bool {
        Self.matches(query, names: searchNames + identifiers)
    }

    public func identifier(preferred: String, matching query: String = "") -> String {
        // A city search retains that city's rules, including future database
        // updates. Selecting the existing named zone preserves its saved city.
        if !Self.words(query).isEmpty {
            let cities = identifiers.filter { Self.matches(query, names: [$0]) }
            if cities.contains(preferred) { return preferred }
            if let city = cities.first { return city }
        }
        return contains(preferred) ? preferred : id
    }

    public func citySummary(matching query: String = "", limit: Int = 3) -> String {
        let ordered = identifiers.sorted {
            let lhs = !query.isEmpty && Self.matches(query, names: [$0])
            let rhs = !query.isEmpty && Self.matches(query, names: [$1])
            return lhs == rhs ? $0 < $1 : lhs
        }
        var seen = Set<String>()
        let cities = ordered.map { $0.split(separator: "/").last.map(String.init) ?? $0 }
            .map { $0.replacingOccurrences(of: "_", with: " ") }
            .filter { seen.insert($0).inserted }
        let shown = cities.prefix(max(1, limit)).joined(separator: ", ")
        return cities.count > max(1, limit) ? "\(shown) +\(cities.count - max(1, limit))" : shown
    }

    private static func words(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "−", with: "-")
            .split(whereSeparator: { $0.isWhitespace || $0 == "/" || $0 == "_" })
            .map(String.init)
    }

    private static func matches(_ query: String, names: [String]) -> Bool {
        let terms = words(query)
        // Prefixes let "new y" find New York without making "EST" match
        // unrelated words such as "Western".
        return names.contains { name in
            let tokens = words(name)
            return terms.allSatisfy { term in tokens.contains { $0.hasPrefix(term) } }
        }
    }
}

public enum TimeZoneCatalog {
    private struct Transition: Hashable {
        let date: Date
        let offset: Int
    }
    private struct Key: Hashable {
        let name: String
        let initialOffset: Int
        let transitions: [Transition]
    }

    public static func groups(at date: Date, including selected: String? = nil,
                              identifiers: [String] = TimeZone.knownTimeZoneIdentifiers,
                              locale: Locale = .current) -> [TimeZoneGroup] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let year = calendar.dateInterval(of: .year, for: date) else { return [] }
        var members: [Key: [String]] = [:]
        var names: [Key: Set<String>] = [:]
        let identifiers = Set(identifiers + (selected.map { [$0] } ?? []))
        for identifier in identifiers.sorted() {
            guard let zone = TimeZone(identifier: identifier) else { continue }
            let name = zone.localizedName(for: .generic, locale: locale) ?? identifier
            var transitions: [Transition] = []
            var samples = [year.start, date]
            var cursor = year.start
            while let next = zone.nextDaylightSavingTimeTransition(after: cursor), next < year.end, next > cursor {
                transitions.append(Transition(date: next, offset: zone.secondsFromGMT(for: next)))
                samples.append(next.addingTimeInterval(1))
                cursor = next.addingTimeInterval(1)
            }
            // Equal offsets today do not imply equal time zones. Compare the
            // full transition schedule for the deadline year as well as its name.
            let key = Key(name: name, initialOffset: zone.secondsFromGMT(for: year.start), transitions: transitions)
            members[key, default: []].append(identifier)
            var aliases = [name, zone.localizedName(for: .standard, locale: locale) ?? name]
            if samples.contains(where: { zone.isDaylightSavingTime(for: $0) }) {
                aliases.append(zone.localizedName(for: .daylightSaving, locale: locale) ?? name)
            }
            for sample in samples {
                if let abbreviation = zone.abbreviation(for: sample) { aliases.append(abbreviation) }
                let offset = zone.secondsFromGMT(for: sample)
                let sign = offset < 0 ? "-" : "+"
                let hours = abs(offset) / 3_600
                let minutes = abs(offset) % 3_600 / 60
                aliases.append(offsetLabel(seconds: offset))
                aliases.append(String(format: "UTC%@%d:%02d", sign, hours, minutes))
                aliases.append(String(format: "GMT%@%d:%02d", sign, hours, minutes))
            }
            names[key, default: []].formUnion(aliases)
        }
        return members.map { key, identifiers in
            TimeZoneGroup(name: key.name, identifiers: identifiers, searchNames: Array(names[key] ?? []))
        }.sorted { $0.name == $1.name ? $0.id < $1.id : $0.name < $1.name }
    }

    public static func offsetLabel(for identifier: String, at date: Date) -> String {
        guard let zone = TimeZone(identifier: identifier) else { return identifier }
        let offset = offsetLabel(seconds: zone.secondsFromGMT(for: date))
        return "\(zone.abbreviation(for: date) ?? identifier) · \(offset)"
    }

    private static func offsetLabel(seconds: Int) -> String {
        String(format: "UTC%@%02d:%02d", seconds < 0 ? "-" : "+", abs(seconds) / 3_600, abs(seconds) % 3_600 / 60)
    }
}
