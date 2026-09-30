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
        for event in saved.events where !event.isAllDay {
            // Selection advances just after the event, including equal-time events.
            let transition = event.date.addingTimeInterval(1)
            if transition > now && transition <= end { dates.insert(transition) }
            let firstDay = Int(floor(now.timeIntervalSince(event.date) / 86_400))
            let lastDay = Int(ceil(end.timeIntervalSince(event.date) / 86_400))
            for day in firstDay...lastDay {
                let boundary = event.date.addingTimeInterval(Double(day) * 86_400)
                // Future countdowns round up seconds, so cross a boundary one second later.
                let change = boundary < event.date ? boundary.addingTimeInterval(1) : boundary
                if change > now && change <= end { dates.insert(change) }
            }
        }
        return dates.sorted()
    }
}
