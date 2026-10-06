#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
xcrun swift build --disable-sandbox -c release
# Keep development bundles out of Spotlight's Applications results. Only the
# installed copy should be registered with Launch Services or opened directly.
APP="$PWD/.build/package/Count Down.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/CountDown "$APP/Contents/MacOS/CountDown"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp LICENSE.md NOTICE "$APP/Contents/Resources/"
xcrun swift scripts/make-icon.swift "$PWD/build"
iconutil -c icns "$PWD/build/AppIcon.iconset" -o "$APP/Contents/Resources/CountDownIcon.icns"
WIDGET="$APP/Contents/PlugIns/CountDownWidget.appex"
# Build a real extension target so Xcode supplies NSExtensionMain and the
# extension run loop. A plain Swift executable exits during WidgetKit startup.
if ! xcodebuild -project Widget/CountDownWidget.xcodeproj -target CountDownWidget \
    -configuration Release -sdk macosx \
    SYMROOT="$PWD/.build/widget-products" OBJROOT="$PWD/.build/widget-intermediates" \
    CODE_SIGNING_ALLOWED=NO > "$PWD/.build/widget-build.log" 2>&1; then
    tail -60 "$PWD/.build/widget-build.log" >&2
    exit 1
fi
ditto "$PWD/.build/widget-products/Release/CountDownWidget.appex" "$WIDGET"
codesign --force --sign - --identifier com.ycliao.CountDown.Widget \
    --entitlements Widget/CountDownWidget.entitlements "$WIDGET"
codesign --force --sign - --identifier com.ycliao.CountDown "$APP"
echo "Built $APP"
