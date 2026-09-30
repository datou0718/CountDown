import AppKit
import SwiftUI

struct CalendarImportView: View {
    @ObservedObject var store: AppStore
    @StateObject private var model: CalendarModel
    @State private var search = ""
    @State private var selected = Set<String>()

    init(store: AppStore) {
        self.store = store
        _model = StateObject(wrappedValue: CalendarModel(isDemo: store.isDemo))
    }

    private var imported: Set<String> { Set(store.events.compactMap(\.calendarImportID)) }
    private var filtered: [CalendarCandidate] {
        model.events.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.calendarName.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "From Apple Calendar") { store.screen = .dashboard }
            Text("Bring your next moment with you.")
                .font(.system(size: 13)).foregroundStyle(AppTheme.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 16)
            if model.isLoading {
                ProgressView("Finding your events…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.error {
                permissionMessage(symbol: "exclamationmark.triangle", title: "Calendar couldn’t load", message: error)
                Button("Try again") { Task { await model.load(requestAccess: true) } }.buttonStyle(.borderedProminent).padding(.bottom, 24)
            } else if !model.hasAccess {
                permissionMessage(symbol: "calendar.badge.plus", title: model.denied ? "Calendar access is off" : "Your calendar, your choice",
                                  message: model.denied ? "Allow Count Down to access calendars in System Settings, then try again." : "Connect Apple Calendar to choose upcoming events. Count Down only reads events and never changes your calendars.")
                if model.denied {
                    Button("Open Calendar privacy settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
                    }.buttonStyle(.bordered).padding(.bottom, 10)
                }
                Button(model.denied ? "Try again" : "Connect Apple Calendar") { Task { await model.load(requestAccess: true) } }
                    .buttonStyle(.borderedProminent).controlSize(.large).padding(.bottom, 24)
            } else {
                TextField("Search events or calendars", text: $search).textFieldStyle(.roundedBorder).controlSize(.large)
                    .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 12)
                HStack {
                    Text("NEXT 12 MONTHS").font(.system(size: 10, weight: .semibold)).tracking(1)
                    Spacer()
                    Button { Task { await model.load() } } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain).help("Refresh calendar events").accessibilityLabel("Refresh calendar events")
                }.foregroundStyle(AppTheme.secondary).padding(.horizontal, 24).padding(.bottom, 10)
                if filtered.isEmpty {
                    Text(search.isEmpty ? "No upcoming events were found in your calendars." : "No matching events.")
                        .foregroundStyle(AppTheme.secondary).font(.system(size: 13)).multilineTextAlignment(.center)
                        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filtered) { candidate in
                                Button {
                                    if selected.contains(candidate.id) { selected.remove(candidate.id) }
                                    else { selected.insert(candidate.id) }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: imported.contains(candidate.id) ? "checkmark.circle.fill" : selected.contains(candidate.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selected.contains(candidate.id) ? AppTheme.navy : AppTheme.secondary).font(.system(size: 18))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(candidate.title).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary).lineLimit(2)
                                            Text(candidate.countdown(isPinned: false).dateLabel()).font(.system(size: 10)).foregroundStyle(AppTheme.secondary)
                                            Text(imported.contains(candidate.id) ? "Already added" : candidate.calendarName).font(.system(size: 10)).foregroundStyle(AppTheme.secondary)
                                        }
                                        Spacer(minLength: 0)
                                    }.padding(13).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12))
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(imported.contains(candidate.id))
                            }
                        }.padding(.horizontal, 20)
                    }
                }
                VStack(spacing: 10) {
                    Text("Events are imported as copies. Changes in Apple Calendar won’t sync to your countdowns.")
                        .font(.system(size: 11)).foregroundStyle(AppTheme.secondary).multilineTextAlignment(.center)
                    Button {
                        if store.importEvents(model.events.filter { selected.contains($0.id) }) { store.screen = .dashboard }
                    } label: { Text(selected.isEmpty ? "Select events to add" : "Add \(selected.count) \(selected.count == 1 ? "countdown" : "countdowns")").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).controlSize(.large).disabled(selected.isEmpty)
                }.padding(22)
            }
        }.task { await model.load() }
    }

    private func permissionMessage(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 17) {
            Image(systemName: symbol).font(.system(size: 42, weight: .light)).foregroundStyle(AppTheme.navy)
            Text(title).font(.system(size: 19, weight: .semibold, design: .rounded))
            Text(message).font(.system(size: 13)).foregroundStyle(AppTheme.secondary).multilineTextAlignment(.center).lineSpacing(4)
        }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
