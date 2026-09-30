import AppKit
import Combine
import CountdownCore
import ServiceManagement
import WidgetKit

enum Screen: Equatable {
    case dashboard
    case editor(UUID?)
    case calendar
    case settings
}

@MainActor
final class AppStore: ObservableObject {
    static let panelWidth: CGFloat = 352
    @Published private(set) var saved = SavedCountdowns()
    @Published var now = Date()
    @Published var screen: Screen = .dashboard
    @Published var errorMessage: String?
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    private let file: EventFile
    private var canSave = true
    let isDemo: Bool

    init(isDemo: Bool = false) {
        self.isDemo = isDemo
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = EventFile(url: support.appendingPathComponent("CountDown/events.json"))
        if isDemo {
            let now = Date()
            saved.events = [
                .init(title: "Kyoto adventure", date: now.addingTimeInterval(12 * 86_400 + 7 * 3_600 + 24 * 60), category: .travel),
                .init(title: "Design launch", date: now.addingTimeInterval(3 * 86_400 + 4 * 3_600), category: .research),
                .init(title: "Birthday dinner", date: now.addingTimeInterval(28 * 86_400), category: .friend)
            ]
        } else {
            do {
                saved = try file.load()
                WidgetCenter.shared.reloadTimelines(ofKind: "CountDown.SelectedEvent")
            }
            catch {
                canSave = false
                errorMessage = "Your saved countdowns could not be read. Your file has been left untouched at \(file.url.path). Restore that file and reopen Count Down.\n\n\(error.localizedDescription)"
            }
        }
    }

    var events: [CountdownEvent] { saved.events }
    var panelHeight: CGFloat {
        switch screen {
        case .dashboard:
            return events.isEmpty ? 310 : min(450, max(280, 150 + CGFloat(events.count) * 120 + (past.isEmpty ? 0 : 28)))
        case .editor: return 470
        case .calendar: return 450
        case .settings: return 450
        }
    }
    var menuBarEvent: CountdownEvent? { saved.menuBarEvent(at: now) }
    var manuallySelectedEvent: CountdownEvent? { saved.manuallySelectedEvent }
    var isAutomaticSelection: Bool { manuallySelectedEvent == nil }
    func isManuallySelected(_ event: CountdownEvent) -> Bool { manuallySelectedEvent?.id == event.id }
    var upcoming: [CountdownEvent] { events.filter { !$0.hasPassed(at: now) }.sorted { $0.date < $1.date } }
    var past: [CountdownEvent] { events.filter { $0.hasPassed(at: now) }.sorted { $0.date > $1.date } }

    @discardableResult
    private func commit(_ next: SavedCountdowns) -> Bool {
        guard canSave else {
            errorMessage = "Saving is paused to protect your unreadable events file. Restore \(file.url.path) and reopen Count Down."
            return false
        }
        do {
            if !isDemo { try file.save(next) }
            saved = next
            if !isDemo { WidgetCenter.shared.reloadTimelines(ofKind: "CountDown.SelectedEvent") }
            return true
        } catch {
            errorMessage = "Your change could not be saved. Please try again.\n\n\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func save(_ event: CountdownEvent) -> Bool {
        guard !event.cleanTitle.isEmpty else { return false }
        var next = saved
        next.upsert(event)
        if event.isPinned { next.selectMenuBarEvent(event.id) }
        else if next.settings.selectedEventID == event.id { next.selectMenuBarEvent(nil) }
        return commit(next)
    }

    @discardableResult
    func importEvents(_ candidates: [CalendarCandidate]) -> Bool {
        var next = saved
        for candidate in candidates {
            next.upsert(candidate.countdown(isPinned: false))
        }
        return commit(next)
    }

    func togglePin(_ event: CountdownEvent) {
        selectMenuBarEvent(isManuallySelected(event) ? nil : event.id)
    }

    func selectMenuBarEvent(_ id: UUID?) {
        var next = saved
        next.selectMenuBarEvent(id)
        commit(next)
    }

    func delete(_ event: CountdownEvent) {
        var next = saved
        next.removeEvent(event.id)
        if commit(next) { screen = .dashboard }
    }

    func setShowTitles(_ value: Bool) {
        var next = saved
        next.settings.showTitlesInMenuBar = value
        commit(next)
    }

    func refreshLoginStatus() {
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { errorMessage = "Launch at login could not be changed.\n\n\(error.localizedDescription)" }
        refreshLoginStatus()
    }
}
