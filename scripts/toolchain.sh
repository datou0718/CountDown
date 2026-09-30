#!/bin/bash
# Shared by build.sh and test.sh after changing to the repository root.
# Prefer a full Xcode installation without changing xcode-select globally.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
if ! xcodebuild -version >/dev/null 2>&1; then
    echo 'Count Down needs the full Xcode app, not just Command Line Tools.' >&2
    echo 'Install and open Xcode, or set DEVELOPER_DIR to its Contents/Developer folder.' >&2
    exit 1
fi
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache"
