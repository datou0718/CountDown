import AppKit
import Combine
import CountdownCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AppStore(
        isDemo: CommandLine.arguments.contains("--demo") || Bundle.main.object(forInfoDictionaryKey: "CountDownDemoMode") as? Bool == true,
        demoStartsEmpty: CommandLine.arguments.contains("--empty-demo")
    )
    private var statusItem: NSStatusItem?
    private lazy var panelController = CountdownPanelController(rootView: RootView(store: store))
    private var observation: AnyCancellable?
    private var timer: Timer?
    private var previewWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Reopening the app should reveal the existing instance instead of adding duplicate status items.
        if !store.isDemo,
           NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.ycliao.CountDown")
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        configureApplicationMenu()
        panelController.onEscape = { [weak self] in
            guard let self else { return }
            if self.store.screen != .dashboard { self.store.screen = .dashboard }
            else { self.hidePanel() }
        }
        panelController.onVisibilityChange = { [weak self] in
            self?.scheduleTick()
            self?.writeStatusDiagnostics()
        }
        resizePanel()
        observation = store.$saved.combineLatest(store.$screen).sink { [weak self] _ in
            // Published sends before the stored value changes.
            DispatchQueue.main.async {
                self?.refreshStatusItem()
                self?.resizePanel()
            }
        }
        refreshStatusItem()
        scheduleTick()
        if diagnosticsPath != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.writeStatusDiagnostics() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wokeUp),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
        if CommandLine.arguments.contains("--preview") || store.isDemo {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: AppStore.panelWidth, height: store.panelHeight),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Count Down Preview"
            window.appearance = NSAppearance(named: .aqua)
            window.contentViewController = NSHostingController(rootView: RootView(store: store))
            window.center()
            window.makeKeyAndOrderFront(nil)
            previewWindow = window
            NSApp.activate(ignoringOtherApps: true)
        } else if store.events.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.showPanel() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "countdown" && $0.host == "open" }) else { return }
        store.screen = .dashboard
        showPanel()
    }

    private func configureApplicationMenu() {
        let main = NSMenu()
        let appMenu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        main.addItem(appItem)
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Count Down", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenu = NSMenu(title: "Edit")
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu
        main.addItem(editItem)
        for (title, action, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"),
                                     ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        NSApp.mainMenu = main
    }

    @objc private func openSettings() {
        store.screen = .settings
        showPanel()
    }

    @objc private func wokeUp() {
        if store.refreshTime() { resizePanel() }
        refreshStatusItem()
        scheduleTick()
    }

    private func scheduleTick() {
        timer?.invalidate()
        let fireDate = CountdownClock.nextTick(after: Date(), events: store.events)
        let nextTimer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.store.refreshTime() { self.resizePanel() }
                self.refreshStatusItem()
                self.scheduleTick()
            }
        }
        // Recompute from the wall clock after every callback, including delayed
        // callbacks. Common modes keep updates running during UI tracking.
        nextTimer.tolerance = 0
        RunLoop.main.add(nextTimer, forMode: .common)
        timer = nextTimer
    }

    private func makeItem(name: String, length: CGFloat = NSStatusItem.variableLength, preferredPosition: Double) -> NSStatusItem {
        // AppKit otherwise inserts new items at the far left, which can be outside
        // the usable menu bar on a notched MacBook. Seed only this app's position;
        // once the user Command-drags it, keep their saved placement.
        let positionKey = "NSStatusItem Preferred Position \(name)"
        if UserDefaults.standard.object(forKey: positionKey) == nil {
            UserDefaults.standard.set(preferredPosition, forKey: positionKey)
        }
        let item = NSStatusBar.system.statusItem(withLength: length)
        item.autosaveName = name
        item.isVisible = true
        item.button?.target = self
        item.button?.action = #selector(togglePanel(_:))
        item.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        return item
    }

    private func refreshStatusItem() {
        // Reuse one item for automatic selection, a manual pin, and the empty
        // state. Its saved position and open panel survive selection changes.
        if statusItem == nil {
            statusItem = makeItem(name: "CountDown.Launcher", preferredPosition: 200)
        }
        guard let item = statusItem, let button = item.button else { return }
        if let event = store.menuBarEvent {
            item.length = NSStatusItem.variableLength
            let value = CountdownValue(event: event, now: store.now)
            let title = event.title.count > 24 ? String(event.title.prefix(23)) + "…" : event.title
            let prefix = store.saved.settings.showTitlesInMenuBar ? title + " · " : ""
            let text = prefix + value.compact
            if button.title != text { button.title = text }
            button.image = nil
            button.imagePosition = .noImage
            button.toolTip = "\(event.title)\n\(value.spoken)\n\(event.dateLabel())"
            button.setAccessibilityLabel("\(event.title), \(value.spoken). Open countdowns")
        } else {
            item.length = NSStatusItem.squareLength
            button.title = ""
            let icon = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "Count Down")?
                .withSymbolConfiguration(.init(pointSize: 14, weight: .medium))
            icon?.isTemplate = true
            button.image = icon
            button.imagePosition = .imageOnly
            button.toolTip = "Count Down — click to add an event"
            button.setAccessibilityLabel("Count Down, add your first countdown")
        }
    }

    @objc private func togglePanel(_ sender: NSStatusBarButton) {
        if panelController.isVisible { hidePanel() }
        else { showPanel() }
    }

    private func showPanel() {
        guard let statusWindow = statusItem?.button?.window else { return }
        store.refreshTime()
        store.refreshLoginStatus()
        resizePanel()
        panelController.show(relativeTo: statusWindow)
    }

    private func hidePanel() { panelController.hide() }

    func applicationDidResignActive(_ notification: Notification) {
        if !panelController.hasAttachedSheet { hidePanel() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController.hide()
        timer?.invalidate()
    }

    private func resizePanel() {
        let size = NSSize(width: AppStore.panelWidth, height: store.panelHeight)
        panelController.resize(to: size)
        previewWindow?.setContentSize(size)
        writeStatusDiagnostics()
    }

    private var diagnosticsPath: String? {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--diagnostics"), arguments.indices.contains(index + 1) {
            return arguments[index + 1]
        }
        return Bundle.main.object(forInfoDictionaryKey: "CountDownDiagnosticsPath") as? String
    }

    // Opt-in local geometry diagnostics. No event names or Calendar data are logged.
    private func writeStatusDiagnostics() {
        guard let path = diagnosticsPath else { return }
        let statusItems = [statusItem].compactMap { $0 }.map { item -> [String: Any] in
            let window = item.button?.window
            return [
                "name": item.autosaveName ?? "",
                "visible": item.isVisible,
                "length": item.length,
                "hasImage": item.button?.image != nil,
                "titleLength": item.button?.title.count ?? 0,
                "buttonFrame": NSStringFromRect(item.button?.frame ?? .zero),
                "windowFrame": NSStringFromRect(window?.frame ?? .zero),
                "windowVisible": window?.isVisible ?? false,
                "windowOccluded": !(window?.occlusionState.contains(.visible) ?? false),
                "screen": window?.screen?.localizedName ?? "none"
            ]
        }
        let screens = NSScreen.screens.map { screen -> [String: Any] in
            ["name": screen.localizedName, "frame": NSStringFromRect(screen.frame),
             "visibleFrame": NSStringFromRect(screen.visibleFrame),
             "topRight": NSStringFromRect(screen.auxiliaryTopRightArea ?? .zero)]
        }
        let report: [String: Any] = ["items": statusItems, "screens": screens,
                                   "panelFrame": NSStringFromRect(panelController.frame), "panelVisible": panelController.isVisible,
                                   "app": Bundle.main.bundleURL.path, "date": Date().description]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
}
