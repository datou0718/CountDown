# Release verification — 1.6.0

Verified on October 6, 2026 using an Apple silicon Mac running macOS 26.5.1, Xcode 26.6, and Swift 6.3.3.

| Check | Result |
| --- | --- |
| Source-only build, with no existing build output or caches | Passed, including from a folder containing spaces |
| Core tests | 34 tests in 7 suites passed |
| Release app and WidgetKit extension | Built successfully |
| Intel app cross-compilation | Passed for `x86_64-apple-macosx14.0`; execution on Intel hardware was not tested |
| Bundle metadata, icon, license, architecture coverage, and code signatures | Passed `scripts/verify-bundle.sh` |
| Empty first-use screen | Verified in an isolated, in-memory preview |
| Create a timed event, change to Asia/Taipei, save, and reopen | Correct date, local time, zone, and countdown |
| Normal installed app after preview | Restored; saved event file checksum unchanged |

The persistence test starts with a missing file/directory and verifies first-save creation and reload. Deadline tests cover exact expiration, expired-pin fallback, widget ordering, saved zones, and daylight-saving transitions.

The macOS 14 deployment target is checked during compilation and packaging. Runtime behavior on macOS 14 and fresh Calendar/login-item permission flows were not re-tested on a separate Mac. GitHub Actions runs `make check` on a fresh hosted macOS checkout; see the repository's Actions tab for its results.

This verifies the source-installation path. It does not certify an ad hoc app bundle for distribution as a notarized download.
