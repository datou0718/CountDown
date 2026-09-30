#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Use the installed app with in-memory sample data, not a second app bundle.
APP="$HOME/Applications/Count Down.app"
if [[ ! -d "$APP" ]]; then
    echo 'Run make install first.' >&2
    exit 1
fi
if pgrep -x CountDown >/dev/null; then
    echo 'Quit Count Down before starting the preview.' >&2
    exit 1
fi
open -n "$APP" --args --demo --preview
