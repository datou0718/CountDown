import Foundation
import Testing
@testable import CountdownCore

struct WidgetScheduleTests {
    @Test func timelineAdvancesAtTimedEventsAndDayBoundaries() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let first = CountdownEvent(title: "First", date: now.addingTimeInterval(300))
        let next = CountdownEvent(title: "Next", date: now.addingTimeInterval(90_000))
        let saved = SavedCountdowns(events: [first, next])
        let dates = WidgetSchedule.dates(for: saved, from: now)
        #expect(dates.first == now)
        #expect(dates.last == now.addingTimeInterval(48 * 3_600))
        #expect(dates == dates.sorted())
        #expect(dates.count == Set(dates).count)
        let switchDate = first.date
        #expect(dates.contains(switchDate))
        #expect(saved.menuBarEvent(at: switchDate)?.id == next.id)
        let lastDay = next.date.addingTimeInterval(-86_400 + 0.001)
        #expect(dates.contains(lastDay))
        #expect(CountdownValue(event: next, now: lastDay).days == 0)
    }

    @Test func timelineUsesLocalMidnightAcrossDaylightSaving() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23)))
        let target = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 9)))
        let event = CountdownEvent(title: "Trip", date: target, isAllDay: true)
        let dates = WidgetSchedule.dates(for: SavedCountdowns(events: [event]), from: now, calendar: calendar)
        #expect(dates.contains(target))
        #expect(CountdownValue(event: event, now: target, calendar: calendar).isToday)
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)))
        #expect(dates.contains(tomorrow))
        #expect(target.timeIntervalSince(tomorrow) == 23 * 3_600)
    }

    @Test func timelineExpiresPinnedEventAtItsDueTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let pinned = CountdownEvent(title: "Pinned", date: now.addingTimeInterval(100))
        var saved = SavedCountdowns(events: [pinned, .init(title: "Later", date: now.addingTimeInterval(1_000))])
        saved.selectMenuBarEvent(pinned.id)
        let dates = WidgetSchedule.dates(for: saved, from: now)
        #expect(dates.contains(pinned.date))
        #expect(saved.menuBarEvent(at: now)?.id == pinned.id)
        #expect(saved.menuBarEvent(at: pinned.date)?.title == "Later")
        #expect(!saved.widgetEvents(at: pinned.date).contains { $0.id == pinned.id })
        #expect(saved.widgetEvents(at: now.addingTimeInterval(1_000)).isEmpty)
    }
}
