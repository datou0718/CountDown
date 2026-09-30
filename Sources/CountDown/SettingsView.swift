import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "The little details") { store.screen = .dashboard }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Menu bar event").font(.system(size: 13, weight: .medium))
                        Picker("Menu bar event", selection: Binding<UUID?>(get: { store.manuallySelectedEvent?.id }, set: { store.selectMenuBarEvent($0) })) {
                            Text("Automatic · nearest upcoming").tag(Optional<UUID>.none)
                            ForEach(store.upcoming + store.past) { event in
                                Text(event.title).tag(Optional(event.id))
                            }
                        }.labelsHidden().pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                        Text("Show one countdown. Choose automatically or keep a specific event pinned.")
                            .font(.system(size: 11)).foregroundStyle(AppTheme.secondary).lineSpacing(3)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Desktop widget", systemImage: "desktopcomputer").font(.system(size: 13, weight: .medium))
                        Text("Right-click your desktop, choose Edit Widgets, then search for Count Down. Add the small or medium widget.")
                            .font(.system(size: 11)).foregroundStyle(AppTheme.secondary).lineSpacing(3)
                        Text("See up to four events: your pinned event first, followed by the nearest upcoming events.")
                            .font(.system(size: 11)).foregroundStyle(AppTheme.secondary).lineSpacing(3)
                    }
                    Divider()
                    Toggle(isOn: Binding(get: { store.saved.settings.showTitlesInMenuBar }, set: { store.setShowTitles($0) })) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Event names in menu bar").font(.system(size: 13, weight: .medium))
                            Text("Turn off for a more compact countdown.").font(.system(size: 11)).foregroundStyle(AppTheme.secondary)
                        }
                    }.toggleStyle(.switch).controlSize(.small).accessibilityLabel("Event names in menu bar")
                    Divider()
                    Toggle(isOn: Binding(get: { store.loginEnabled }, set: { store.setLaunchAtLogin($0) })) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Launch at login").font(.system(size: 13, weight: .medium))
                            Text("Your moments, ready when you are.").font(.system(size: 11)).foregroundStyle(AppTheme.secondary)
                        }
                    }.toggleStyle(.switch).controlSize(.small).disabled(store.isDemo).accessibilityLabel("Launch at login")
                    if store.loginNeedsApproval {
                        Button("Approve in Login Items settings") { SMAppService.openSystemSettingsLoginItems() }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Saved on this Mac", systemImage: "internaldrive").font(.system(size: 13, weight: .medium))
                        Text("Your countdowns stay on this device. Calendar imports are separate copies; your original events are never changed.")
                            .font(.system(size: 12)).foregroundStyle(AppTheme.secondary).lineSpacing(4)
                    }
                }.padding(18)
            }
            HStack {
                Text("Count Down \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .font(.system(size: 11)).foregroundStyle(AppTheme.secondary)
                Spacer()
                Button("Quit Count Down") { NSApp.terminate(nil) }.keyboardShortcut("q", modifiers: .command)
            }.padding(18)
        }.onAppear { store.refreshLoginStatus() }
    }
}
