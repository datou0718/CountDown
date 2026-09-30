#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SOURCE="$PWD/.build/package/Count Down.app"
APP="$HOME/Applications/Count Down.app"
LEGACY_APP="$HOME/Applications/CountDown.app"
REGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
if [[ ! -d "$SOURCE" ]]; then
    echo 'Run make build first.' >&2
    exit 1
fi
if pgrep -x CountDown >/dev/null; then
    echo 'Quit Count Down before installing the update. Your events will be preserved.' >&2
    exit 1
fi
mkdir -p "$HOME/Applications"
codesign --verify --deep --strict "$SOURCE"
ditto "$SOURCE" "$APP"
codesign --verify --deep --strict "$APP"
# Retire the former name only after the new bundle is installed and verified.
# Keep a hidden backup without an .app suffix so it is not another application.
if [[ -d "$LEGACY_APP" ]] && [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$LEGACY_APP/Contents/Info.plist")" == 'com.ycliao.CountDown' ]]; then
    mkdir -p "$PWD/.build/retired"
    BACKUP=$(mktemp -d "$PWD/.build/retired/rename.XXXXXX")
    "$REGISTER" -u "$LEGACY_APP"
    mv "$LEGACY_APP" "$BACKUP/CountDown.buildbundle"
fi
"$REGISTER" -f "$APP"
pluginkit -a "$APP/Contents/PlugIns/CountDownWidget.appex"
# macOS can keep an extension process alive across a local bundle update.
# Release our old helper so the next refresh uses the newly installed layout.
if pgrep -x CountDownWidget >/dev/null; then
    pkill -x CountDownWidget
fi
echo "Installed $APP"
