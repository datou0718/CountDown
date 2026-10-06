#!/bin/bash
# Shared by build.sh and test.sh after changing to the repository root.
# Prefer a full Xcode installation without changing xcode-select globally.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
if ! XCODE_VERSION=$(xcodebuild -version 2>/dev/null); then
    echo 'Count Down needs the full Xcode app, not just Command Line Tools.' >&2
    echo 'Install and open Xcode, or set DEVELOPER_DIR to its Contents/Developer folder.' >&2
    exit 1
fi
XCODE_MAJOR=$(printf '%s\n' "$XCODE_VERSION" | awk '/^Xcode / { split($2, version, "."); print version[1] }')
if [[ ! "$XCODE_MAJOR" =~ ^[0-9]+$ ]] || (( XCODE_MAJOR < 16 )); then
    echo 'Count Down requires Xcode 16 or later (Swift 6).' >&2
    exit 1
fi
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache"
