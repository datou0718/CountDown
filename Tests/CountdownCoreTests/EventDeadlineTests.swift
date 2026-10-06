import Foundation
import Testing
@testable import CountdownCore

struct EventDeadlineTests {
    private func zone(_ identifier: String) throws -> TimeZone { try #require(TimeZone(identifier: identifier)) }
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0,
                      in identifier: String) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try zone(identifier)
        return try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)))
    }

    @Test func timedEventsDisappearAtTheirDeadlineIncludingManualPins() {
        let due = Date(timeIntervalSince1970: 1_800_000_000)
        let event = CountdownEvent(title: "Due", date: due)
        let next = CountdownEvent(title: "Next", date: due.addingTimeInterval(60))
        var saved = SavedCountdowns(events: [event, next])
        saved.selectMenuBarEvent(event.id)
        #expect(saved.menuBarEvent(at: due.addingTimeInterval(-0.001))?.id == event.id)
        #expect(saved.menuBarEvent(at: due)?.id == next.id)
        #expect(saved.activeEvents(at: due).map(\.id) == [next.id])
        #expect(saved.widgetEvents(at: due).map(\.id) == [next.id])
        #expect(saved.menuBarEvent(at: next.date) == nil)
        #expect(saved.activeEvents(at: next.date).isEmpty)
        #expect(saved.widgetEvents(at: next.date).isEmpty)
        #expect(saved.events.count == 2) // Removal from displays does not destroy saved records.
    }

    @Test func allDayExpirationUsesTheEventZoneAcrossDaylightSaving() throws {
        let start = try date(2026, 11, 1, in: "America/New_York")
        let end = try date(2026, 11, 2, in: "America/New_York")
        let event = CountdownEvent(title: "All day", date: start, isAllDay: true, timeZoneIdentifier: "America/New_York")
        var elsewhere = Calendar(identifier: .gregorian)
        elsewhere.timeZone = try zone("Asia/Taipei")
        #expect(end.timeIntervalSince(start) == 25 * 3_600)
        #expect(event.expirationDate(calendar: elsewhere) == end)
        #expect(!event.hasPassed(at: end.addingTimeInterval(-1), calendar: elsewhere))
        #expect(event.hasPassed(at: end, calendar: elsewhere))
        #expect(CountdownValue(event: event, now: end.addingTimeInterval(-1), calendar: elsewhere).isToday)
    }

    @Test func widgetSchedulesMidnightInTheEventZone() throws {
        let now = try date(2026, 10, 6, 23, 50, in: "Asia/Taipei")
        let midnight = try date(2026, 10, 7, in: "Asia/Taipei")
        let event = CountdownEvent(title: "All day", date: now, isAllDay: true, timeZoneIdentifier: "Asia/Taipei")
        var elsewhere = Calendar(identifier: .gregorian)
        elsewhere.timeZone = try zone("America/New_York")
        let saved = SavedCountdowns(events: [event])
        #expect(WidgetSchedule.dates(for: saved, from: now, calendar: elsewhere).contains(midnight))
        #expect(saved.widgetEvents(at: midnight, calendar: elsewhere).isEmpty)
    }

    @Test func changingZonesPreservesEnteredTimeAndUsesSeasonalOffset() throws {
        for month in [1, 7] {
            let original = try date(2027, month, 10, 9, 30, in: "Asia/Taipei")
            let result = try #require(EventTime.changingTimeZone(of: original, from: zone("Asia/Taipei"),
                                                                to: zone("America/New_York")))
            #expect(result == (try date(2027, month, 10, 9, 30, in: "America/New_York")))
            #expect(result.timeIntervalSince(original) == Double(month == 1 ? 13 : 12) * 3_600)
        }
    }

    @Test func nonexistentLocalTimeIsRejected() throws {
        let original = try date(2027, 3, 14, 2, 30, in: "UTC")
        #expect(try EventTime.changingTimeZone(of: original, from: zone("UTC"), to: zone("America/New_York")) == nil)
    }

    @Test func eventTimeZoneSurvivesSavingAndLegacyDatesDoNotMove() throws {
        let due = try date(2027, 1, 10, 9, 30, in: "Asia/Taipei")
        let event = CountdownEvent(title: "Deadline", date: due, timeZoneIdentifier: "Asia/Taipei")
        let bytes = try JSONEncoder().encode(event)
        #expect(try JSONDecoder().decode(CountdownEvent.self, from: bytes) == event)
        var legacy = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        legacy.removeValue(forKey: "timeZoneIdentifier")
        let restored = try JSONDecoder().decode(CountdownEvent.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(restored.date == due)
        #expect(restored.timeZoneIdentifier == nil)
    }
}
