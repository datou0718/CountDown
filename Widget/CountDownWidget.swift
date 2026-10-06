import Darwin
import Foundation
import OSLog
import SwiftUI
import WidgetKit

private let navy = Color(red: 1 / 255, green: 33 / 255, blue: 105 / 255)
private let widgetLog = Logger(subsystem: "com.ycliao.CountDown.Widget", category: "EventLoading")

struct CountdownEntry: TimelineEntry {
    let date: Date
    let events: [CountdownEvent]
    var needsApp = false
}

struct CountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry { sample() }

    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> Void) {
        if context.isPreview { completion(sample()); return }
        let now = Date()
        do { completion(CountdownEntry(date: now, events: try load().widgetEvents(at: now))) }
        catch { completion(CountdownEntry(date: now, events: [], needsApp: true)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> Void) {
        let now = Date()
        do {
            let saved = try load()
            let entries = WidgetSchedule.dates(for: saved, from: now).map {
                CountdownEntry(date: $0, events: saved.widgetEvents(at: $0))
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        } catch {
            completion(Timeline(entries: [CountdownEntry(date: now, events: [], needsApp: true)],
                                policy: .after(now.addingTimeInterval(15 * 60))))
        }
    }

    private func load() throws -> SavedCountdowns {
        // This local Mac build shares only its existing events file with the
        // sandboxed widget, using the narrowly scoped read-only entitlement.
        guard let home = getpwuid(getuid())?.pointee.pw_dir else { throw CocoaError(.fileReadNoSuchFile) }
        let url = URL(fileURLWithPath: String(cString: home), isDirectory: true)
            .appendingPathComponent("Library/Application Support/CountDown/events.json")
        do {
            let saved = try EventFile(url: url).load()
            // Log counts only, so native widget refreshes can be diagnosed
            // without putting event names or dates in system logs.
            widgetLog.notice("Loaded \(saved.events.count, privacy: .public) saved events; displaying \(saved.widgetEvents(at: Date()).count, privacy: .public)")
            return saved
        } catch {
            let error = error as NSError
            widgetLog.error("Could not load events: \(error.domain, privacy: .public) code \(error.code, privacy: .public)")
            throw error
        }
    }

    func sample() -> CountdownEntry {
        let now = Date()
        let examples: [(String, EventCategory, Int)] = [
            ("Paper deadline", .research, 7), ("Final exam", .school, 12),
            ("Kyoto trip", .travel, 24), ("Dinner", .friend, 31)
        ]
        return CountdownEntry(date: now, events: examples.map { title, category, days in
            CountdownEvent(title: title, date: Calendar.current.date(byAdding: .day, value: days, to: now)!,
                           isAllDay: true, category: category)
        })
    }
}

struct CountdownWidgetView: View {
    let entry: CountdownEntry
    let family: WidgetFamily

    var body: some View {
        Group {
            if !entry.events.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: isSmall ? 8 : 12),
                                         count: isSmall ? 2 : 4), spacing: isSmall ? 8 : 12) {
                    ForEach(entry.events.prefix(4)) { event in
                        eventTile(event)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "hourglass").font(.system(size: 24))
                    Text(entry.needsApp ? "Open Count Down" : "Your next moment").font(.headline)
                    Text(entry.needsApp ? "Open the app to load your countdowns." : "Add an event in Count Down to see it here.")
                        .font(.system(size: 12)).opacity(0.7)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(navy)
        .widgetURL(URL(string: "countdown://open"))
    }

    private var isSmall: Bool { family == .systemSmall }

    private func eventTile(_ event: CountdownEvent) -> some View {
        VStack(spacing: isSmall ? 2 : 6) {
            Image(systemName: event.category.symbol)
                .font(.system(size: isSmall ? 14 : 23, weight: .medium))
                .frame(width: isSmall ? 22 : 48, height: isSmall ? 22 : 48)
                .background(navy.opacity(0.08), in: Circle())
            Text(event.title).font(.system(size: isSmall ? 10 : 12, weight: .medium))
                .lineLimit(2).minimumScaleFactor(0.8).multilineTextAlignment(.center)
                .frame(height: isSmall ? 20 : 30)
            countdown(event)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.category.name), \(event.title), \(CountdownValue(event: event, now: entry.date).spoken)")
    }

    @ViewBuilder
    private func countdown(_ event: CountdownEvent) -> some View {
        let value = CountdownValue(event: event, now: entry.date)
        Group {
            if value.isAllDay {
                Text(value.compact)
            } else if value.days > 0 {
                Text("\(value.days)d")
            } else {
                // If macOS presents the next entry late, stop at zero instead
                // of counting up while the expired tile is being replaced.
                // The bounded initializer rounds up (unlike .timer), so offset
                // its endpoint by one second to retain our whole-second floor.
                Text(timerInterval: entry.date...max(entry.date, event.date.addingTimeInterval(-1)), countsDown: true)
            }
        }
        .font(.system(size: isSmall ? 12 : 19, weight: .semibold, design: .rounded))
        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
    }
}

#if !WIDGET_PREVIEW
private struct CountdownWidgetRoot: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountdownEntry
    var body: some View { CountdownWidgetView(entry: entry, family: family) }
}

@main
struct CountDownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CountDown.SelectedEvent", provider: CountdownProvider()) { entry in
            CountdownWidgetRoot(entry: entry)
                .containerBackground(for: .widget) { Color.white }
        }
        .configurationDisplayName("Count Down")
        .description("Up to four events with their icons, names, and countdowns.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable(false)
    }
}
#endif
