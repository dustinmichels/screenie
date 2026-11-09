#!/usr/bin/env bash
# Build the Debug app and run it from build/ in this terminal (Ctrl-C quits).
# Quits any running Screenie first, since both copies share a bundle ID.
set -euo pipefail

cd "$(dirname "$0")/.."

xcodebuild -project Screenie.xcodeproj -scheme Screenie -configuration Debug \
  -destination 'generic/platform=macOS' -derivedDataPath build/DerivedData build -quiet
scripts/quit.sh
exec build/DerivedData/Build/Products/Debug/Screenie.app/Contents/MacOS/Screenie
