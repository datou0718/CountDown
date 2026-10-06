import Foundation

/// Entries at every change that affects selection or the displayed whole-day count.
/// Short timed countdowns use SwiftUI's live timer text between these entries.
public enum WidgetSchedule {
    public static func dates(for saved: SavedCountdowns, from now: Date, calendar: Calendar = .current) -> [Date] {
        let end = now.addingTimeInterval(48 * 3_600)
        var dates: Set<Date> = [now, end]
        var midnight = calendar.startOfDay(for: now)
        while let next = calendar.date(byAdding: .day, value: 1, to: midnight), next <= end {
            dates.insert(next)
            midnight = next
        }
        for event in saved.activeEvents(at: now, calendar: calendar) {
            let transition = event.expirationDate(calendar: calendar)
            if transition > now && transition <= end { dates.insert(transition) }
            if event.isAllDay {
                let eventCalendar = event.eventCalendar(calendar)
                var day = eventCalendar.startOfDay(for: now)
                while let next = eventCalendar.date(byAdding: .day, value: 1, to: day), next <= end {
                    dates.insert(next)
                    day = next
                }
                continue
            }
            let firstDay = Int(floor(now.timeIntervalSince(event.date) / 86_400))
            let lastDay = Int(ceil(end.timeIntervalSince(event.date) / 86_400))
            for day in firstDay...lastDay {
                let boundary = event.date.addingTimeInterval(Double(day) * 86_400)
                // Native timers truncate whole seconds; future day counts drop
                // immediately after the boundary, without an extra second.
                let change = boundary < event.date ? boundary.addingTimeInterval(0.001) : boundary
                if change > now && change < transition && change <= end { dates.insert(change) }
            }
        }
        return dates.sorted()
    }
}
