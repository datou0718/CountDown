import AppKit
import SwiftUI

/// Keep both display and editing in the selected event zone by setting the
/// native control's calendar and time zone explicitly on every update.
struct DueDateField: View {
    let label: String
    @Binding var selection: Date
    let timeZone: TimeZone
    let showsTime: Bool

    var body: some View {
        HStack {
            Text(label)
            ZonedDatePicker(selection: $selection, timeZone: timeZone, showsTime: showsTime, label: label)
                .fixedSize()
            Spacer(minLength: 0)
        }
    }
}

private struct ZonedDatePicker: NSViewRepresentable {
    @Binding var selection: Date
    let timeZone: TimeZone
    let showsTime: Bool
    let label: String

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

    func makeNSView(context: Context) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textField
        picker.datePickerMode = .single
        picker.datePickerElements = showsTime ? .hourMinute : .yearMonthDay
        picker.isBezeled = true
        picker.font = .systemFont(ofSize: 13)
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.dateChanged(_:))
        picker.setAccessibilityLabel(label)
        return picker
    }

    func updateNSView(_ picker: NSDatePicker, context: Context) {
        context.coordinator.selection = $selection
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        if picker.calendar != calendar { picker.calendar = calendar }
        if picker.timeZone != timeZone { picker.timeZone = timeZone }
        if picker.dateValue != selection { picker.dateValue = selection }
    }

    @MainActor
    final class Coordinator: NSObject {
        var selection: Binding<Date>

        init(selection: Binding<Date>) { self.selection = selection }

        @objc func dateChanged(_ sender: NSDatePicker) {
            selection.wrappedValue = sender.dateValue
        }
    }
}
