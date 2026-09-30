import Foundation

public enum MenuBarMode: String, Codable, Sendable {
    case automatic
    case pinned
}

public struct CountdownSettings: Codable, Equatable, Sendable {
    public var showTitlesInMenuBar = true
    public var menuBarMode: MenuBarMode = .automatic
    public var selectedEventID: UUID?
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case showTitlesInMenuBar, menuBarMode, selectedEventID
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let mode = try values.decodeIfPresent(MenuBarMode.self, forKey: .menuBarMode)
        menuBarMode = mode ?? .automatic
        selectedEventID = try values.decodeIfPresent(UUID.self, forKey: .selectedEventID)
        // Upgrade the old multiple-pin display to automatic selection with names.
        showTitlesInMenuBar = mode == nil ? true : try values.decodeIfPresent(Bool.self, forKey: .showTitlesInMenuBar) ?? true
    }
}

public struct SavedCountdowns: Codable, Equatable, Sendable {
    public var version = 1
    public var events: [CountdownEvent]
    public var settings: CountdownSettings

    public init(events: [CountdownEvent] = [], settings: CountdownSettings = .init()) {
        self.events = events
        self.settings = settings
    }

    public var manuallySelectedEvent: CountdownEvent? {
        guard settings.menuBarMode == .pinned else { return nil }
        return events.first { $0.id == settings.selectedEventID }
    }

    public func menuBarEvent(at now: Date, calendar: Calendar = .current) -> CountdownEvent? {
        if let manuallySelectedEvent { return manuallySelectedEvent }
        let chronological = events.sorted {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
        }
        return chronological.first { !$0.hasPassed(at: now, calendar: calendar) } ?? chronological.last
    }

    public func widgetEvents(at now: Date, calendar: Calendar = .current, limit: Int = 4) -> [CountdownEvent] {
        guard limit > 0 else { return [] }
        let pinned = manuallySelectedEvent
        let remaining = events.filter { $0.id != pinned?.id }.sorted { lhs, rhs in
            let lhsPast = lhs.hasPassed(at: now, calendar: calendar)
            let rhsPast = rhs.hasPassed(at: now, calendar: calendar)
            if lhsPast != rhsPast { return !lhsPast }
            if lhs.date == rhs.date { return lhs.id.uuidString < rhs.id.uuidString }
            return lhsPast ? lhs.date > rhs.date : lhs.date < rhs.date
        }
        let ordered = (pinned.map { [$0] } ?? []) + remaining
        return Array(ordered.prefix(limit))
    }

    public mutating func selectMenuBarEvent(_ id: UUID?) {
        let selected = id.flatMap { id in events.first { $0.id == id } }
        settings.menuBarMode = selected == nil ? .automatic : .pinned
        settings.selectedEventID = selected?.id
        // Keep legacy pin fields consistent for saved files from earlier versions.
        for index in events.indices { events[index].isPinned = events[index].id == selected?.id }
    }

    public mutating func removeEvent(_ id: UUID) {
        events.removeAll { $0.id == id }
        if settings.selectedEventID == id { selectMenuBarEvent(nil) }
    }

    public mutating func upsert(_ event: CountdownEvent) {
        var cleaned = event
        cleaned.title = event.cleanTitle
        guard !cleaned.title.isEmpty else { return }
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = cleaned
        } else if let importID = event.calendarImportID,
                  events.contains(where: { $0.calendarImportID == importID }) {
            return
        } else {
            events.append(cleaned)
        }
    }
}

public struct EventFile: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }

    public func load() throws -> SavedCountdowns {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return .init() }
        let result = try JSONDecoder().decode(SavedCountdowns.self, from: data)
        guard result.version == 1 else { throw CocoaError(.fileReadUnknown) }
        guard Set(result.events.map(\.id)).count == result.events.count else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return result
    }

    public func save(_ value: SavedCountdowns) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
