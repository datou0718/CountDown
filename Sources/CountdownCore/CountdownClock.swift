import Foundation

/// Keeps app updates on the same second boundaries as native widget timers.
public enum CountdownClock {
    public static func nextTick(after now: Date, events: [CountdownEvent]) -> Date {
        // Clock seconds cover all-day changes and automatic event selection.
        var next = Date(timeIntervalSinceReferenceDate: floor(now.timeIntervalSinceReferenceDate) + 1)
        for event in events where !event.isAllDay {
            // Imported dates are usually whole seconds. Manually entered dates
            // can retain fractional seconds, so include their timer boundaries.
            let elapsed = now.timeIntervalSince(event.date)
            let boundary = event.date.addingTimeInterval(floor(elapsed) + 1)
            next = min(next, boundary)
        }
        // A future countdown drops just after the boundary, rather than at it.
        return next.addingTimeInterval(0.001)
    }
}
