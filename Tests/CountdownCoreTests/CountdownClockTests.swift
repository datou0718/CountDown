import Foundation
import Testing
@testable import CountdownCore

struct CountdownClockTests {
    private let epoch = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func wholeSecondTicksAgreeWithTheLiveTimerAtMinuteAndHourBoundaries() {
        for remaining in [60.0, 3_600.0, 86_400.0] {
            let event = CountdownEvent(title: "Example", date: epoch.addingTimeInterval(remaining))
            let now = epoch.addingTimeInterval(-0.25)
            let tick = CountdownClock.nextTick(after: now, events: [event])
            #expect(tick > epoch && tick.timeIntervalSince(epoch) < 0.01)
            let value = CountdownValue(event: event, now: tick)
            let total = value.days * 86_400 + value.hours * 3_600 + value.minutes * 60 + value.seconds
            #expect(total == Int(remaining) - 1)
        }
    }

    @Test func fractionalEventDatesTickAtTheirOwnBoundaries() {
        let event = CountdownEvent(title: "Example", date: epoch.addingTimeInterval(60.75))
        let now = epoch.addingTimeInterval(0.25)
        let tick = CountdownClock.nextTick(after: now, events: [event])
        #expect(tick > epoch.addingTimeInterval(0.75))
        #expect(tick.timeIntervalSince(epoch) < 0.76)
        #expect(CountdownValue(event: event, now: now).compact == "1m")
        #expect(CountdownValue(event: event, now: tick).compact == "59s")
    }

    @Test func delayedCallbacksRealignInsteadOfAccumulatingDrift() {
        let late = epoch.addingTimeInterval(15.6)
        let tick = CountdownClock.nextTick(after: late, events: [])
        #expect(tick > epoch.addingTimeInterval(16))
        #expect(tick.timeIntervalSince(epoch) < 16.01)
        #expect(tick.timeIntervalSince(late) < 0.41)
    }
}
