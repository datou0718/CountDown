#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/.build/package/Count Down.app"
WIDGET="$APP/Contents/PlugIns/CountDownWidget.appex"
PLISTBUDDY=/usr/libexec/PlistBuddy

fail() { echo "Bundle check failed: $*" >&2; exit 1; }
value() { "$PLISTBUDDY" -c "Print :$2" "$1/Contents/Info.plist"; }

[[ -x "$APP/Contents/MacOS/CountDown" ]] || fail 'app executable is missing'
[[ -x "$WIDGET/Contents/MacOS/CountDownWidget" ]] || fail 'widget executable is missing'
[[ -s "$APP/Contents/Resources/CountDownIcon.icns" ]] || fail 'app icon is missing'
cmp LICENSE.md "$APP/Contents/Resources/LICENSE.md"
cmp NOTICE "$APP/Contents/Resources/NOTICE"
plutil -lint "$APP/Contents/Info.plist" "$WIDGET/Contents/Info.plist"
[[ "$(value "$APP" CFBundleIdentifier)" == 'com.ycliao.CountDown' ]] || fail 'app identity changed'
[[ "$(value "$WIDGET" CFBundleIdentifier)" == 'com.ycliao.CountDown.Widget' ]] || fail 'widget identity changed'
[[ "$(value "$APP" LSUIElement)" == 'true' ]] || fail 'menu bar app setting is missing'
[[ "$(value "$WIDGET" NSExtension:NSExtensionPointIdentifier)" == 'com.apple.widgetkit-extension' ]] || fail 'widget extension declaration is missing'
for key in CFBundleShortVersionString CFBundleVersion LSMinimumSystemVersion; do
    [[ "$(value "$APP" "$key")" == "$(value "$WIDGET" "$key")" ]] || fail "$key differs between app and widget"
done
[[ "$(value "$APP" LSMinimumSystemVersion)" == '14.0' ]] || fail 'unexpected deployment requirement'
WIDGET_ARCHS=$(lipo -archs "$WIDGET/Contents/MacOS/CountDownWidget")
for arch in $(lipo -archs "$APP/Contents/MacOS/CountDown"); do
    [[ " $WIDGET_ARCHS " == *" $arch "* ]] || fail "widget does not support app architecture $arch"
done
ENTITLEMENTS=$(codesign --display --entitlements :- "$WIDGET" 2>/dev/null)
[[ "$(printf '%s' "$ENTITLEMENTS" | plutil -extract com\\.apple\\.security\\.app-sandbox raw -o - -)" == 'true' ]] || fail 'widget sandbox entitlement is missing'
codesign --verify --deep --strict "$APP"
echo "Verified Count Down $(value "$APP" CFBundleShortVersionString), build $(value "$APP" CFBundleVersion)."
