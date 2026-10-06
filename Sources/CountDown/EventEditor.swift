import CountdownCore
import SwiftUI

struct EventEditor: View {
    @ObservedObject var store: AppStore
    let event: CountdownEvent?
    @State private var title: String
    @State private var date: Date
    @State private var allDay: Bool
    @State private var category: EventCategory
    @State private var pinned: Bool
    @State private var timeZoneIdentifier: String
    @FocusState private var titleFocused: Bool

    init(store: AppStore, event: CountdownEvent?) {
        self.store = store
        self.event = event
        _title = State(initialValue: event?.title ?? "")
        _date = State(initialValue: event?.date ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
        _allDay = State(initialValue: event?.isAllDay ?? false)
        _category = State(initialValue: event?.category ?? .research)
        _pinned = State(initialValue: event.map { store.isManuallySelected($0) } ?? false)
        _timeZoneIdentifier = State(initialValue: event?.timeZone.identifier ?? TimeZone.current.identifier)
    }

    private var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar
    }

    private var zoneSelection: Binding<String> {
        Binding(get: { timeZoneIdentifier }, set: { identifier in
            guard let zone = TimeZone(identifier: identifier),
                  let converted = EventTime.changingTimeZone(of: date, from: timeZone, to: zone) else {
                store.errorMessage = "That local time does not exist in the selected time zone because the clocks move forward. Choose another due time first."
                return
            }
            date = converted
            timeZoneIdentifier = identifier
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: event == nil ? "A new moment" : "Edit your moment") { store.screen = .dashboard }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("EVENT NAME")
                        TextField("What are you looking forward to?", text: $title)
                            .textFieldStyle(.roundedBorder).controlSize(.large).focused($titleFocused)
                            .accessibilityLabel("Event name")
                            .onChange(of: title) { _, new in if new.count > 100 { title = String(new.prefix(100)) } }
                    }
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            fieldLabel("DUE")
                            Spacer()
                            Toggle("All day", isOn: $allDay).toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                        }
                        DueDateField(label: "Due date", selection: $date, timeZone: timeZone, showsTime: false)
                        if !allDay {
                            DueDateField(label: "Due time", selection: $date, timeZone: timeZone, showsTime: true)
                        }
                        TimeZonePicker(selection: zoneSelection, date: date)
                        Text(allDay ? "Expires at the end of this day in the selected zone." : "Changing time zone keeps the date and time you entered.")
                            .font(.system(size: 10)).foregroundStyle(AppTheme.secondary)
                    }
                    .environment(\.timeZone, timeZone).environment(\.calendar, calendar)
                    VStack(alignment: .leading, spacing: 10) {
                        fieldLabel("CATEGORY")
                        HStack(spacing: 4) {
                            ForEach(EventCategory.allCases, id: \.self) { option in
                                Button { category = option } label: {
                                    VStack(spacing: 7) {
                                        Image(systemName: option.symbol).font(.system(size: 18, weight: .medium)).frame(height: 21)
                                        Text(option.name).font(.system(size: 10, weight: .medium)).lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity).frame(height: 58)
                                    .foregroundStyle(AppTheme.navy)
                                    .background(AppTheme.navy.opacity(category == option ? 0.12 : 0.035), in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppTheme.navy.opacity(category == option ? 0.65 : 0.08), lineWidth: 1))
                                }.buttonStyle(.plain).accessibilityLabel(option.name)
                                    .accessibilityValue(category == option ? "Selected" : "Not selected")
                                    .help(option.name)
                            }
                        }
                    }
                    Toggle(isOn: $pinned) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Keep this event in menu bar").font(.system(size: 13, weight: .medium))
                            Text("Use this event instead of automatic selection.").font(.system(size: 11)).foregroundStyle(AppTheme.secondary)
                        }
                    }.toggleStyle(.switch).controlSize(.small).accessibilityLabel("Keep this event in menu bar")
                    if let calendarName = event?.calendarName {
                        Label("Copy from \(calendarName). Calendar changes won’t sync.", systemImage: "calendar")
                            .font(.system(size: 10)).foregroundStyle(AppTheme.secondary)
                    }
                }.padding(.horizontal, 18).padding(.vertical, 16)
            }
            HStack(spacing: 12) {
                Button("Cancel") { store.screen = .dashboard }.keyboardShortcut(.cancelAction)
                    .buttonStyle(.bordered).controlSize(.large)
                Button { save() } label: {
                    Text(event == nil ? "Create countdown" : "Save changes").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(16)
        }.onAppear { titleFocused = event == nil }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(AppTheme.secondary)
    }

    private func save() {
        var result = event ?? CountdownEvent(title: title, date: date)
        result.title = title
        result.date = allDay ? calendar.startOfDay(for: date) : calendar.dateInterval(of: .minute, for: date)?.start ?? date
        result.timeZoneIdentifier = timeZoneIdentifier
        result.isAllDay = allDay
        result.category = category
        result.isPinned = pinned
        if store.save(result) { store.screen = .dashboard }
    }
}
