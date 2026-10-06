# Developing Count Down

Count Down uses Swift 6, SwiftUI, AppKit, EventKit, and WidgetKit, with no third-party package dependencies. The deployment target is macOS 14.

## Toolchain

Install Xcode 16 or later and open it to finish setup. Build and test scripts prefer `/Applications/Xcode.app` when `DEVELOPER_DIR` is unset; they do not change the system-wide `xcode-select` setting.

For Xcode in another location:

```sh
export DEVELOPER_DIR="/path/to/Xcode.app/Contents/Developer"
make test
make build
```

The full Xcode installation is needed for the WidgetKit extension target and Swift Testing modules.

## Commands

| Command | Result |
| --- | --- |
| `make test` | Run core tests with Swift Testing |
| `make build` | Build and locally sign the app and widget |
| `make check` | Run tests, build, and verify bundle metadata, architectures, resources, and signatures |
| `make install` | Build and install to `~/Applications/Count Down.app` |
| `make run` | Build, install, and open the app |

Quit Count Down before installing. Build output stays under `.build/` and `build/`, both ignored by Git. Only the installed app is registered with Launch Services. The installer also retires the former `CountDown.app` name, if present, and restarts the widget helper after updates.

## Code layout

| Location | Responsibility |
| --- | --- |
| `Sources/CountdownCore/` | Event categories, countdown arithmetic, selection rules, JSON persistence, and widget timeline scheduling |
| `Sources/CountDown/CountDownApp.swift` | Application entry point |
| `Sources/CountDown/AppDelegate.swift` | Application lifecycle, the single status item, timer, menus, and URL handling |
| `Sources/CountDown/CountdownPanelController.swift` | Panel sizing, menu bar alignment, Escape handling, and outside-click dismissal |
| `Sources/CountDown/AppStore.swift` | Observable app state, saved changes, widget refresh requests, and login settings |
| `Sources/CountDown/CalendarModel.swift` | Calendar authorization and event loading through an actor |
| `Sources/CountDown/*View.swift`, `EventEditor.swift`, `ViewComponents.swift` | Individual screens and shared theme/header components |
| `Sources/CountDown/DueDateField.swift`, `TimeZonePicker.swift` | Native date/time fields with an explicit zone and searchable zone selection |
| `Widget/` | Native WidgetKit extension and its Xcode target |
| `Tests/CountdownCoreTests/` | Countdown, persistence, migration, menu selection, and widget tests |
| `scripts/` | Shared toolchain setup, build, install, icon generation, and previews |

Keep countdown and selection logic in `CountdownCore`. Keep panel geometry independent of event state: changing a pin must not move an open panel. Resizing holds its top-left corner in place, and reopening aligns to the status window’s trailing edge.

`TimeZoneCatalog` groups the system's city identifiers by generic zone name and their UTC-offset/DST transition schedule for the deadline year. The picker builds the catalog when opened, then searches city aliases, names, both seasonal abbreviations, and offsets. Matching today's offset alone must not merge zones with different rules. Choosing a city retains that IANA identifier; choosing the current named zone preserves its saved city. This catalog is used by the app editor only, so it is not needed in the widget target.

## Widget integration

The main app is built by SwiftPM. The widget uses a real Xcode app-extension target, which supplies `NSExtensionMain` and the extension run loop. Do not replace it with a hand-bundled command-line executable.

The widget target compiles the core source files directly. If you add a core file used by the widget, add it to `Widget/CountDownWidget.xcodeproj` as well.

The widget kind is `CountDown.SelectedEvent`. Keeping that identifier lets existing installed widgets update in place. The app reloads its timeline after loading, successfully saving events, or an active event expiring. Timelines cover 48 hours, including each event's exact expiration, midnights in all-day events' time zones, and changes to whole-day countdowns. Short timed countdowns use bounded SwiftUI timer text so they stop at zero if macOS delays switching entries.

`SavedCountdowns.activeEvents(at:)` is the shared expiration filter for the dashboard, menu bar, settings, and widget. Expired pins fall back to automatic selection. Expiration hides saved records rather than deleting them; editor lookup uses the full saved list so an event expiring during editing retains its identity. Timed deadlines are absolute `Date` values with an optional IANA time-zone identifier for editing and display. Legacy records without that field keep their original date and use the current zone. All-day events expire at the end of their date in their event zone, including 23- and 25-hour days.

This local build uses an ad hoc signature and a sandboxed widget with read-only access to the existing `~/Library/Application Support/CountDown/events.json` file. The widget resolves the actual user home rather than its sandbox container. It never accesses Calendar directly. A build intended for App Store distribution should use a provisioned App Group for shared data; public distribution also needs appropriate signing and notarization.

Preserve the app bundle identifier, widget kind, and storage path when changing display names. The file format remains version 1; migration supports categories from older icon-based event files and upgrades the former multiple-pin setting to automatic selection. Unreadable data must never be overwritten.

## Previews

After installing, quit Count Down and run:

```sh
bash scripts/preview.sh
```

This opens the installed app with disposable, in-memory events and Calendar examples. It does not read or save your countdown file, refresh real widgets, or allow login-setting changes. Quit the preview and reopen Count Down normally to return to your events.

Use `bash scripts/preview.sh --empty` to start with no events and check the first-use screen, creation flow, expiration, and empty state. Its events are also in memory only.

To render sample widgets without modifying saved events:

```sh
mkdir -p .build
swiftc -D WIDGET_PREVIEW -parse-as-library \
  -module-cache-path .build/clang-module-cache \
  Sources/CountdownCore/*.swift Widget/CountDownWidget.swift \
  scripts/preview-widgets.swift -o .build/preview-widgets
.build/preview-widgets .build/widget-previews
```

## Verification

Run `make check` before installing a change. Core tests cover time boundaries, daylight saving time, all-day events, imports, persisted pins, category migration, invalid files, and widget ordering/timelines. Persistence tests start at a nonexistent storage path, create the data directory on first save, and reload the saved events and settings.

The GitHub workflow runs `make check` from a fresh checkout without build caches. It does not install the app, publish binaries, or require signing credentials. GUI behavior, Calendar permissions, login items, and native widget presentation still need checks on a real Mac.

See the [1.6.0 verification record](VERIFICATION.md) for the tested environment, results, and limits.

For panel or UI changes, also check the installed app:

1. Open the panel, switch between short and long event names, and confirm it stays in place.
2. Open an editor or settings, then press Escape to return. Resizing should keep the top edge against the menu bar.
3. Open Delete and cancel it; verify the event is unchanged.
4. Check the small and medium widget layouts with multiple events.
5. Restore any event selections changed during verification.
6. In the empty preview, create a timed event, select a different zone, save, and reopen it. Confirm the date/time and zone survive editing. Check the empty state after all events expire.

Optional geometry diagnostics can help confirm panel placement. Quit the app first, then run:

```sh
open "$HOME/Applications/Count Down.app" --args \
  --diagnostics "$PWD/.build/panel-position.json"
```

The local report includes window frames and menu item dimensions, without event names or Calendar content. Quit and reopen normally to turn it off. Widget loading logs use the subsystem `com.ycliao.CountDown.Widget` and report event counts or error codes, not event details.

## Distribution

The supported GitHub installation path is to clone the source and run `make run` on the destination Mac. Build scripts select Xcode's Swift toolchain with `xcrun`; no developer account or third-party dependency download is needed.

`make build` produces a host-architecture app with an embedded WidgetKit extension and an ad hoc signature. It is suitable for local installation. It is not a universal, Developer ID signed, notarized release. Do not present that bundle as a ready-to-open download for every Mac. A public binary release needs the intended architectures, appropriate distribution signing, hardened runtime/notarization, and validation on a separate Mac. App Store distribution also needs a provisioned App Group instead of the local file-sharing entitlement.

Keep `LICENSE.md` and `NOTICE` with source copies and built apps. The build includes both in `Contents/Resources`. Releases must retain the noncommercial terms.
