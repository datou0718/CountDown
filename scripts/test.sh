#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/toolchain.sh
xcrun swift test --disable-sandbox --scratch-path .build/tests
