#!/usr/bin/env bash
# Run the Debug app against fake screenshots in build/demo-screenshots, for docs captures that
# don't show your real files. Ctrl-C quits. Add a "new" screenshot (shows the dot) from another
# terminal with: swift scripts/make-samples.swift build/demo-screenshots --new
set -euo pipefail

cd "$(dirname "$0")/.."

folder="$PWD/build/demo-screenshots"
rm -rf "$folder"
swift scripts/make-samples.swift "$folder" >/dev/null
SCREENIE_FOLDER="$folder" exec scripts/dev.sh
