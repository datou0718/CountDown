import Combine
import CountdownCore
import EventKit
import Foundation

struct CalendarCandidate: Identifiable, Sendable {
    let id: String
    let title: String
    let date: Date
    let isAllDay: Bool
    let calendarName: String
    var timeZoneIdentifier: String? = nil

    func countdown(isPinned: Bool) -> CountdownEvent {
        CountdownEvent(title: title, date: date, isAllDay: isAllDay,
                       isPinned: isPinned, calendarImportID: id, calendarName: calendarName,
                       timeZoneIdentifier: timeZoneIdentifier)
    }
}

private actor CalendarReader {
    private let store = EKEventStore()

    func read(requestAccess: Bool) async throws -> [CalendarCandidate]? {
        if EKEventStore.authorizationStatus(for: .event) != .fullAccess {
            guard requestAccess else { return nil }
            guard try await store.requestFullAccessToEvents() else { return nil }
        }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .year, value: 1, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        var seen = Set<String>()
        return store.events(matching: predicate)
            .filter { $0.isAllDay ? $0.startDate >= start : $0.startDate >= Date() }
            .sorted { $0.startDate < $1.startDate }
            .compactMap { event in
                let id = "\(event.calendarItemIdentifier)|\(event.startDate.timeIntervalSinceReferenceDate)"
                guard seen.insert(id).inserted else { return nil }
                return CalendarCandidate(id: id, title: event.title?.isEmpty == false ? event.title : "Untitled event",
                                         date: event.startDate, isAllDay: event.isAllDay,
                                         calendarName: event.calendar.title,
                                         timeZoneIdentifier: event.timeZone?.identifier ?? TimeZone.current.identifier)
            }
    }
}

@MainActor
final class CalendarModel: ObservableObject {
    @Published var events: [CalendarCandidate] = []
    @Published var isLoading = false
    @Published var hasAccess = false
    @Published var denied = false
    @Published var error: String?
    private let reader = CalendarReader()
    private let isDemo: Bool

    init(isDemo: Bool = false) { self.isDemo = isDemo }

    func load(requestAccess: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        if isDemo {
            hasAccess = true
            if events.isEmpty {
                events = [
                    CalendarCandidate(id: "demo-concert", title: "An evening of live music", date: Date().addingTimeInterval(172_800), isAllDay: false, calendarName: "Personal · Preview"),
                    CalendarCandidate(id: "demo-holiday", title: "A long weekend", date: Date().addingTimeInterval(604_800), isAllDay: true, calendarName: "Personal · Preview")
                ]
            }
            return
        }
        do {
            let result = try await reader.read(requestAccess: requestAccess)
            hasAccess = result != nil
            events = result ?? []
            let status = EKEventStore.authorizationStatus(for: .event)
            denied = status == .denied || status == .restricted || status == .writeOnly
        } catch {
            self.error = error.localizedDescription
        }
    }
}
