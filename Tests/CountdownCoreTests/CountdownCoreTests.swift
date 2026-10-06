import Foundation
import Testing
@testable import CountdownCore

struct CountdownCoreTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    static let boundaries: [(TimeInterval, String)] = [
        (1_063_440.0, "12d 7h"),
        (3_660.0, "1h 1m"), (60.0, "1m"), (59.0, "59s"),
        (1.1, "1s"), (59.75, "59s"), (60.75, "1m"), (3_599.75, "59m"),
        (0.0, "Now"), (-1.0, "1s ago"), (-1.1, "1s ago"), (-86_400.0, "1d 0h ago")
    ]
    @Test(arguments: boundaries)
    func countdownBoundaries(_ example: (TimeInterval, String)) {
        let event = CountdownEvent(title: "Launch", date: now.addingTimeInterval(example.0))
        #expect(CountdownValue(event: event, now: now).compact == example.1)
    }

    @Test func allDayUsesCalendarDaysAcrossDaylightSaving() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let before = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23)))
        let target = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 9)))
        let event = CountdownEvent(title: "Trip", date: target, isAllDay: true)
        #expect(CountdownValue(event: event, now: before, calendar: calendar).compact == "2d")
        #expect(CountdownValue(event: event, now: target.addingTimeInterval(43_200), calendar: calendar).compact == "Today")
        #expect(!event.hasPassed(at: target.addingTimeInterval(43_200), calendar: calendar))
        #expect(event.hasPassed(at: target.addingTimeInterval(86_400), calendar: calendar))
    }

    @Test func pastAllDayCountdown() {
        let event = CountdownEvent(title: "Yesterday", date: now.addingTimeInterval(-86_400), isAllDay: true)
        #expect(CountdownValue(event: event, now: now).compact == "1d ago")
    }

    @Test func persistenceRoundTripIncludesPinsAndSettings() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("events.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let file = EventFile(url: url)
        #expect(try file.load().events.isEmpty)
        var saved = SavedCountdowns(events: [.init(title: "Birthday", date: now, isAllDay: true, category: .friend, isPinned: false)])
        saved.settings.showTitlesInMenuBar = true
        try file.save(saved)
        #expect(try file.load() == saved)
    }

    @Test func corruptFileIsNotSilentlyReplaced() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let bytes = Data("not valid JSON".utf8)
        try bytes.write(to: url)
        #expect(throws: (any Error).self) { try EventFile(url: url).load() }
        #expect(try Data(contentsOf: url) == bytes)
    }

    @Test func duplicateIDsAreRejectedOnLoad() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let event = CountdownEvent(title: "Duplicate", date: now)
        let file = EventFile(url: url)
        try file.save(SavedCountdowns(events: [event, event]))
        #expect(throws: (any Error).self) { try file.load() }
    }

    @Test func unsupportedVersionIsRejected() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        var saved = SavedCountdowns()
        saved.version = 2
        let file = EventFile(url: url)
        try file.save(saved)
        #expect(throws: (any Error).self) { try file.load() }
    }

    @Test func editingPreservesIdentityAndDoesNotDuplicate() {
        var saved = SavedCountdowns()
        var event = CountdownEvent(title: "  Holiday  ", date: now)
        saved.upsert(event)
        #expect(saved.events.first?.title == "Holiday")
        event.title = "New title"
        event.isPinned = false
        saved.upsert(event)
        #expect(saved.events.count == 1)
        #expect(saved.events.first == event)
        saved.upsert(.init(title: " \n ", date: now))
        #expect(saved.events.count == 1)
    }

    @Test func calendarImportIsIdempotentButSeparateOccurrencesRemain() {
        var saved = SavedCountdowns()
        saved.upsert(.init(title: "Meeting", date: now, calendarImportID: "series|occurrence1"))
        saved.upsert(.init(title: "Meeting", date: now, calendarImportID: "series|occurrence1"))
        saved.upsert(.init(title: "Meeting", date: now.addingTimeInterval(604_800), calendarImportID: "series|occurrence2"))
        #expect(saved.events.count == 2)
    }
}
