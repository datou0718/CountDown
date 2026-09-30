import CountdownCore
import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "hourglass").foregroundStyle(.white)
                Text("COUNT DOWN").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(2.3)
                Spacer()
                if store.isDemo { Text("PREVIEW").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.75)) }
                Button { store.screen = .settings } label: { Image(systemName: "gearshape").frame(width: 28, height: 28) }
                    .buttonStyle(.plain).foregroundStyle(.white.opacity(0.85)).help("Settings").accessibilityLabel("Settings")
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
            .foregroundStyle(.white).background(AppTheme.navy)

            if store.events.isEmpty {
                VStack(spacing: 14) {
                    ZStack {
                        Circle().fill(AppTheme.navy.opacity(0.09)).frame(width: 98, height: 98)
                        Circle().stroke(AppTheme.navy.opacity(0.16), lineWidth: 1).frame(width: 122, height: 122)
                        Image(systemName: "hourglass").font(.system(size: 40, weight: .light)).foregroundStyle(AppTheme.navy)
                    }.padding(.bottom, 12)
                    Text("Something to look forward to.").font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text("A trip, a birthday, your next big thing.\nKeep it a glance away in your menu bar.")
                        .font(.system(size: 13)).foregroundStyle(AppTheme.secondary).multilineTextAlignment(.center).lineSpacing(4)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if store.upcoming.isEmpty {
                            Text("All caught up. Add your next moment below.")
                                .font(.system(size: 12)).foregroundStyle(AppTheme.secondary).padding(.vertical, 12)
                        }
                        ForEach(store.upcoming) { event in EventCard(store: store, event: event) }
                        if !store.past.isEmpty {
                            Text("PAST MOMENTS").font(.system(size: 10, weight: .semibold)).tracking(1.5)
                                .foregroundStyle(AppTheme.secondary).padding(.top, 10)
                            ForEach(store.past) { event in EventCard(store: store, event: event) }
                        }
                    }.padding(.horizontal, 14).padding(.vertical, 12)
                }
            }

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button { store.screen = .editor(nil) } label: {
                        Label("New event", systemImage: "plus").frame(maxWidth: .infinity).frame(height: 24)
                    }.buttonStyle(.borderedProminent).controlSize(.regular).keyboardShortcut("n", modifiers: .command)
                    Button { store.screen = .calendar } label: {
                        Label("From Calendar", systemImage: "calendar").frame(maxWidth: .infinity).frame(height: 24)
                    }.buttonStyle(.bordered).controlSize(.regular)
                }
                HStack(spacing: 5) {
                    Image(systemName: store.isAutomaticSelection ? "arrow.triangle.2.circlepath" : "pin.fill").font(.system(size: 9))
                    Text(store.events.isEmpty ? "Your next event will appear in the menu bar" : store.isAutomaticSelection ? "Automatic · nearest upcoming event" : "Pinned · \(store.manuallySelectedEvent?.title ?? "")")
                        .font(.system(size: 11)).lineLimit(1)
                    if !store.isAutomaticSelection {
                        Spacer(minLength: 6)
                        Button("Use automatic") { store.selectMenuBarEvent(nil) }
                            .font(.system(size: 11, weight: .medium)).buttonStyle(.plain).foregroundStyle(AppTheme.navy)
                    }
                }.foregroundStyle(AppTheme.secondary)
            }.padding(14).background(AppTheme.background)
        }
    }
}

private struct EventCard: View {
    @ObservedObject var store: AppStore
    let event: CountdownEvent
    @State private var confirmDelete = false

    private var value: CountdownValue { CountdownValue(event: event, now: store.now) }
    private let accent = AppTheme.navy
    private var isPinned: Bool { store.isManuallySelected(event) }
    private var isShownInMenuBar: Bool { store.menuBarEvent?.id == event.id }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 10) {
                    Image(systemName: event.category.symbol).font(.system(size: 17, weight: .medium)).foregroundStyle(accent)
                        .frame(width: 37, height: 37).background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
                        .accessibilityLabel(event.category.name).help(event.category.name)
                    Button { store.screen = .editor(event.id) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppTheme.navy).lineLimit(1)
                            Text(event.dateLabel()).font(.system(size: 10)).foregroundStyle(AppTheme.secondary).lineLimit(1)
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).help("Edit \(event.title)")
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if value.isToday {
                        Text(value.isAllDay ? "Today" : "Now").font(.system(size: 28, weight: .medium, design: .rounded))
                    } else if event.isAllDay {
                        number(value.days, unit: value.days == 1 ? "day" : "days")
                    } else {
                        if value.days > 0 { number(value.days, unit: "days") }
                        if value.days > 0 || value.hours > 0 { number(value.hours, unit: "hrs") }
                        number(value.minutes, unit: "min")
                        if value.days == 0 { number(value.seconds, unit: "sec") }
                    }
                    if value.isPast {
                        Text("ago").font(.system(size: 10, weight: .medium)).foregroundStyle(AppTheme.secondary)
                    }
                    Spacer(minLength: 0)
                }.accessibilityElement(children: .ignore).accessibilityLabel(value.spoken)
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 2) {
                actionButton(isPinned ? "Unpin \(event.title) and use automatic selection" : "Pin \(event.title)",
                             symbol: isPinned ? "pin.fill" : "pin") { store.togglePin(event) }
                actionButton("Edit \(event.title)", symbol: "pencil") { store.screen = .editor(event.id) }
                actionButton("Delete \(event.title)", symbol: "trash") { confirmDelete = true }
            }
        }
        .padding(12)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isShownInMenuBar ? accent.opacity(0.35) : .primary.opacity(0.07), lineWidth: 1))
        .alert("Delete “\(event.title)”?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { store.delete(event) }
        } message: { Text("This removes the countdown. Your Apple Calendar is not changed.") }
    }

    private func actionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .medium)).foregroundStyle(accent)
                .frame(width: 28, height: 28).contentShape(Rectangle())
        }.buttonStyle(.plain).help(title).accessibilityLabel(title)
    }

    private func number(_ value: Int, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(String(value)).font(.system(size: 27, weight: .medium, design: .rounded)).monospacedDigit()
            Text(unit).font(.system(size: 10)).foregroundStyle(AppTheme.secondary)
        }
    }
}
