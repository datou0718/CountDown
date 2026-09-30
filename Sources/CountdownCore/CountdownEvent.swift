import Foundation

public enum EventCategory: String, Codable, CaseIterable, Sendable {
    case research, school, travel, love, friend

    public var name: String { rawValue.capitalized }

    public var symbol: String {
        switch self {
        case .research: return "doc.text"
        case .school: return "graduationcap"
        case .travel: return "airplane"
        case .love: return "heart"
        case .friend: return "person.2"
        }
    }

    fileprivate init(legacySymbol: String?) {
        switch legacySymbol {
        case "graduationcap", "calendar": self = .school
        case "airplane": self = .travel
        case "heart": self = .love
        case "gift", "music.note", "person.2": self = .friend
        default: self = .research
        }
    }
}

public struct CountdownEvent: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var date: Date
    public var isAllDay: Bool
    public var category: EventCategory
    public var isPinned: Bool
    public var calendarImportID: String?
    public var calendarName: String?

    public init(id: UUID = UUID(), title: String, date: Date, isAllDay: Bool = false,
                category: EventCategory = .research, isPinned: Bool = false,
                calendarImportID: String? = nil, calendarName: String? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.isAllDay = isAllDay
        self.category = category
        self.isPinned = isPinned
        self.calendarImportID = calendarImportID
        self.calendarName = calendarName
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, date, isAllDay, category, isPinned, calendarImportID, calendarName
    }

    private enum LegacyCodingKeys: String, CodingKey { case symbol }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        date = try values.decode(Date.self, forKey: .date)
        isAllDay = try values.decode(Bool.self, forKey: .isAllDay)
        isPinned = try values.decode(Bool.self, forKey: .isPinned)
        calendarImportID = try values.decodeIfPresent(String.self, forKey: .calendarImportID)
        calendarName = try values.decodeIfPresent(String.self, forKey: .calendarName)
        if let savedCategory = try values.decodeIfPresent(EventCategory.self, forKey: .category) {
            category = savedCategory
        } else {
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            category = EventCategory(legacySymbol: try legacy.decodeIfPresent(String.self, forKey: .symbol))
        }
    }

    public var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    public func hasPassed(at now: Date, calendar: Calendar = .current) -> Bool {
        isAllDay ? calendar.startOfDay(for: date) < calendar.startOfDay(for: now) : date < now
    }

    public func dateLabel() -> String {
        if isAllDay { return date.formatted(date: .abbreviated, time: .omitted) + " · All day" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

public struct CountdownValue: Equatable, Sendable {
    public let days: Int
    public let hours: Int
    public let minutes: Int
    public let seconds: Int
    public let isPast: Bool
    public let isToday: Bool
    public let isAllDay: Bool

    public init(event: CountdownEvent, now: Date, calendar: Calendar = .current) {
        isAllDay = event.isAllDay
        if event.isAllDay {
            let difference = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                                      to: calendar.startOfDay(for: event.date)).day ?? 0
            days = abs(difference)
            hours = 0
            minutes = 0
            seconds = 0
            isPast = difference < 0
            isToday = difference == 0
        } else {
            let difference = event.date.timeIntervalSince(now)
            let total = Int(difference > 0 ? ceil(difference) : floor(abs(difference)))
            days = total / 86_400
            hours = (total % 86_400) / 3_600
            minutes = (total % 3_600) / 60
            seconds = total % 60
            isPast = difference <= -1
            isToday = abs(difference) < 1
        }
    }

    public var compact: String {
        if isToday { return isAllDay ? "Today" : "Now" }
        let value: String
        if isAllDay { value = "\(days)d" }
        else if days > 0 { value = "\(days)d \(hours)h" }
        else if hours > 0 { value = "\(hours)h \(minutes)m" }
        else if minutes > 0 { value = "\(minutes)m" }
        else { value = "\(seconds)s" }
        return isPast ? value + " ago" : value
    }

    public var spoken: String {
        if isToday { return isAllDay ? "Today" : "Now" }
        var parts: [String] = []
        if days > 0 { parts.append("\(days) \(days == 1 ? "day" : "days")") }
        if !isAllDay {
            if hours > 0 { parts.append("\(hours) \(hours == 1 ? "hour" : "hours")") }
            if minutes > 0 { parts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")") }
            if parts.isEmpty { parts.append("\(seconds) \(seconds == 1 ? "second" : "seconds")") }
        }
        return parts.joined(separator: ", ") + (isPast ? " ago" : " remaining")
    }
}
