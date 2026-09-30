import SwiftUI

struct RootView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Group {
            switch store.screen {
            case .dashboard: DashboardView(store: store)
            case .editor(let id): EventEditor(store: store, event: store.events.first { $0.id == id }).id(id)
            case .calendar: CalendarImportView(store: store)
            case .settings: SettingsView(store: store)
            }
        }
        .frame(width: AppStore.panelWidth, height: store.panelHeight)
        .background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .foregroundStyle(AppTheme.navy)
        .tint(AppTheme.navy)
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .alert("Count Down", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}
