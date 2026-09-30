import AppKit
import SwiftUI

/// Owns the menu bar panel's geometry and dismissal, independently of event data.
@MainActor
final class CountdownPanelController {
    private let panel = CountdownPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
    private var outsideClickMonitor: Any?

    var onVisibilityChange: (() -> Void)?
    var onEscape: (() -> Void)? {
        get { panel.onEscape }
        set { panel.onEscape = newValue }
    }
    var isVisible: Bool { panel.isVisible }
    var hasAttachedSheet: Bool { panel.attachedSheet != nil }
    var frame: NSRect { panel.frame }

    init(rootView: some View) {
        panel.title = "Count Down"
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        let controller = NSHostingController(rootView: rootView)
        controller.view.appearance = NSAppearance(named: .aqua)
        panel.contentViewController = controller
    }

    func show(relativeTo statusWindow: NSWindow) {
        if !panel.isVisible { position(relativeTo: statusWindow) }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                Task { @MainActor in self?.hide() }
            }
        }
        onVisibilityChange?()
    }

    func hide() {
        panel.orderOut(nil)
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
        onVisibilityChange?()
    }

    func resize(to size: NSSize) {
        guard panel.frame.size != size else { return }
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        panel.setContentSize(size)
        // Content grows downward from the same menu-bar position. Pin changes
        // need neither resizing nor repositioning.
        if panel.isVisible { panel.setFrameTopLeftPoint(topLeft) }
    }

    private func position(relativeTo statusWindow: NSWindow) {
        guard let screen = statusWindow.screen else { return }
        // Use the window's trailing edge, which stays put while the title is
        // being laid out. Centering under the title shifts with each event name.
        let anchor = statusWindow.frame
        let bounds = screen.visibleFrame.insetBy(dx: 8, dy: 0)
        let x = min(max(anchor.maxX - panel.frame.width, bounds.minX), bounds.maxX - panel.frame.width)
        // Attach directly to the menu bar with no vertical gap.
        let y = max(bounds.minY, min(anchor.minY, bounds.maxY) - panel.frame.height)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

@MainActor
private final class CountdownPanel: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
}
