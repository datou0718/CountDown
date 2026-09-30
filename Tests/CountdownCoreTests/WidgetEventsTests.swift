import Foundation
import Testing
@testable import CountdownCore

struct WidgetEventsTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func widgetShowsFourNearestUpcomingEvents() {
        let events = (1...6).map { CountdownEvent(title: "Event \($0)", date: now.addingTimeInterval(Double($0) * 3_600)) }
        let past = CountdownEvent(title: "Past", date: now.addingTimeInterval(-100))
        let saved = SavedCountdowns(events: [past] + events.reversed())
        #expect(saved.widgetEvents(at: now) == Array(events.prefix(4)))
        #expect(saved.widgetEvents(at: events[0].date.addingTimeInterval(1)) == Array(events[1...4]))
    }

    @Test func pinnedEventLeadsWithoutDuplicatesAndDeletingItRestoresOrder() {
        let events = (1...5).map { CountdownEvent(title: "Event \($0)", date: now.addingTimeInterval(Double($0) * 3_600)) }
        var saved = SavedCountdowns(events: events)
        saved.selectMenuBarEvent(events[4].id)
        #expect(saved.widgetEvents(at: now).map(\.id) == ([events[4]] + Array(events.prefix(3))).map(\.id))
        saved.selectMenuBarEvent(events[0].id)
        #expect(saved.widgetEvents(at: now).map(\.id) == events.prefix(4).map(\.id))
        saved.removeEvent(events[0].id)
        #expect(saved.widgetEvents(at: now) == Array(events.dropFirst()))
    }

    @Test func fewerEventsFillWithRecentPastAndEmptyStaysEmpty() {
        let older = CountdownEvent(title: "Older", date: now.addingTimeInterval(-200))
        let recent = CountdownEvent(title: "Recent", date: now.addingTimeInterval(-100))
        let future = CountdownEvent(title: "Future", date: now.addingTimeInterval(100))
        var saved = SavedCountdowns(events: [older, future, recent])
        #expect(saved.widgetEvents(at: now) == [future, recent, older])
        saved.selectMenuBarEvent(older.id)
        #expect(saved.widgetEvents(at: now).map(\.id) == [older, future, recent].map(\.id))
        #expect(saved.widgetEvents(at: now, limit: 1).map(\.id) == [older.id])
        #expect(saved.widgetEvents(at: now, limit: 0).isEmpty)
        #expect(SavedCountdowns().widgetEvents(at: now).isEmpty)
    }
}
