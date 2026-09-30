import Foundation
import Testing
@testable import CountdownCore

struct EventCategoryTests {
    @Test(arguments: EventCategory.allCases)
    func categoryPersistsWithoutCustomColors(_ category: EventCategory) throws {
        let event = CountdownEvent(title: "A moment", date: Date(timeIntervalSince1970: 1_800_000_000), category: category)
        let data = try JSONEncoder().encode(event)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["category"] as? String == category.rawValue)
        #expect(object["symbol"] == nil)
        #expect(object["color"] == nil)
        #expect(try JSONDecoder().decode(CountdownEvent.self, from: data) == event)

        // An explicit category takes precedence if a legacy icon is also present.
        object["symbol"] = "gift"
        object["color"] = "rose"
        let mixedData = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(CountdownEvent.self, from: mixedData) == event)
    }

    static let legacyIcons: [(String, EventCategory)] = [
        ("sparkles", .research), ("flag.checkered", .research),
        ("graduationcap", .school), ("calendar", .school),
        ("airplane", .travel), ("heart", .love),
        ("gift", .friend), ("music.note", .friend), ("unknown", .research)
    ]

    @Test(arguments: legacyIcons)
    func legacyFilesPreserveEventsAndMenuBarSelection(_ example: (String, EventCategory)) throws {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let legacy: [String: Any] = [
            "version": 1,
            "settings": ["menuBarMode": "pinned", "selectedEventID": id.uuidString, "showTitlesInMenuBar": true],
            "events": [[
                "id": id.uuidString, "title": "My saved event", "date": date.timeIntervalSinceReferenceDate,
                "isAllDay": true, "isPinned": true, "symbol": example.0, "color": "rose",
                "calendarImportID": "calendar|occurrence", "calendarName": "Personal"
            ]]
        ]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("events.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = try JSONSerialization.data(withJSONObject: legacy)
        try original.write(to: url)
        let file = EventFile(url: url)
        let loaded = try file.load()
        #expect(loaded.events == [CountdownEvent(id: id, title: "My saved event", date: date, isAllDay: true,
                                               category: example.1, isPinned: true,
                                               calendarImportID: "calendar|occurrence", calendarName: "Personal")])
        #expect(loaded.manuallySelectedEvent?.id == id)
        #expect(loaded.settings.showTitlesInMenuBar)
        #expect(try Data(contentsOf: url) == original)
        try file.save(loaded)
        #expect(try file.load() == loaded)
    }
}
