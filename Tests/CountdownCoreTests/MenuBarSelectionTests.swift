import Foundation
import Testing
@testable import CountdownCore

struct MenuBarSelectionTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func automaticChoosesNearestUpcomingAndAdvances() {
        let past = CountdownEvent(title: "Past", date: now.addingTimeInterval(-30))
        let next = CountdownEvent(title: "Next", date: now.addingTimeInterval(60))
        let later = CountdownEvent(title: "Later", date: now.addingTimeInterval(120), isPinned: true)
        let saved = SavedCountdowns(events: [later, past, next])
        #expect(saved.menuBarEvent(at: now)?.id == next.id)
        #expect(saved.menuBarEvent(at: now.addingTimeInterval(61))?.id == later.id)
        #expect(saved.menuBarEvent(at: now.addingTimeInterval(121))?.id == later.id)
        #expect(SavedCountdowns().menuBarEvent(at: now) == nil)
    }

    @Test func manualSelectionOverridesAutomaticUntilReleased() {
        let next = CountdownEvent(title: "Next", date: now.addingTimeInterval(60))
        let later = CountdownEvent(title: "Later", date: now.addingTimeInterval(120))
        var saved = SavedCountdowns(events: [next, later])
        saved.selectMenuBarEvent(later.id)
        #expect(saved.menuBarEvent(at: now)?.id == later.id)
        #expect(saved.menuBarEvent(at: now.addingTimeInterval(180))?.id == later.id)
        saved.selectMenuBarEvent(next.id)
        #expect(saved.events.filter(\.isPinned).map(\.id) == [next.id])
        #expect(saved.menuBarEvent(at: now)?.id == next.id)
        saved.selectMenuBarEvent(nil)
        #expect(saved.settings.menuBarMode == .automatic)
        #expect(saved.manuallySelectedEvent == nil)
        #expect(saved.menuBarEvent(at: now)?.id == next.id)
    }

    @Test func deletingThePinnedEventRestoresAutomaticSelection() {
        let first = CountdownEvent(title: "First", date: now.addingTimeInterval(60))
        let second = CountdownEvent(title: "Second", date: now.addingTimeInterval(120))
        var saved = SavedCountdowns(events: [first, second])
        saved.selectMenuBarEvent(second.id)
        saved.removeEvent(second.id)
        #expect(saved.settings.menuBarMode == .automatic)
        #expect(saved.settings.selectedEventID == nil)
        #expect(saved.menuBarEvent(at: now)?.id == first.id)
        saved.removeEvent(first.id)
        #expect(saved.menuBarEvent(at: now) == nil)
    }

    @Test func allDayTodayRemainsEligibleUntilTomorrow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let midday = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12)))
        let today = CountdownEvent(title: "Today", date: calendar.startOfDay(for: midday), isAllDay: true)
        let tomorrow = CountdownEvent(title: "Tomorrow", date: midday.addingTimeInterval(86_400))
        let saved = SavedCountdowns(events: [tomorrow, today])
        #expect(saved.menuBarEvent(at: midday, calendar: calendar)?.id == today.id)
        #expect(saved.menuBarEvent(at: midday.addingTimeInterval(43_200), calendar: calendar)?.id == tomorrow.id)
    }

    @Test func updatingDatesReevaluatesAutomaticSelection() {
        var first = CountdownEvent(title: "Rescheduled", date: now.addingTimeInterval(60))
        let second = CountdownEvent(title: "Other", date: now.addingTimeInterval(120))
        var saved = SavedCountdowns(events: [first, second])
        first.date = now.addingTimeInterval(180)
        saved.upsert(first)
        #expect(saved.menuBarEvent(at: now)?.id == second.id)
    }

    @Test func manualChoiceSurvivesSavingAndRelaunching() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let first = CountdownEvent(title: "First", date: now.addingTimeInterval(60))
        let second = CountdownEvent(title: "Second", date: now.addingTimeInterval(120))
        var saved = SavedCountdowns(events: [first, second])
        saved.selectMenuBarEvent(second.id)
        saved.settings.showTitlesInMenuBar = false
        try EventFile(url: url).save(saved)
        let restored = try EventFile(url: url).load()
        #expect(restored.menuBarEvent(at: now)?.id == second.id)
        #expect(restored.settings.menuBarMode == .pinned)
        #expect(!restored.settings.showTitlesInMenuBar)
    }

    @Test func legacyMultiplePinsUpgradeToAutomaticWithEventNames() throws {
        let nearest = CountdownEvent(title: "Nearest", date: now.addingTimeInterval(60), isPinned: true)
        let later = CountdownEvent(title: "Later", date: now.addingTimeInterval(120), isPinned: true)
        let saved = SavedCountdowns(events: [later, nearest])
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        legacy["settings"] = ["showTitlesInMenuBar": false]
        let restored = try JSONDecoder().decode(SavedCountdowns.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(restored.events == saved.events)
        #expect(restored.settings.menuBarMode == .automatic)
        #expect(restored.settings.showTitlesInMenuBar)
        #expect(restored.menuBarEvent(at: now)?.id == nearest.id)
    }

    @Test func missingManualSelectionFallsBackGracefully() {
        let next = CountdownEvent(title: "Next", date: now.addingTimeInterval(60))
        var saved = SavedCountdowns(events: [next])
        saved.settings.menuBarMode = .pinned
        saved.settings.selectedEventID = UUID()
        #expect(saved.manuallySelectedEvent == nil)
        #expect(saved.menuBarEvent(at: now)?.id == next.id)
    }
}
