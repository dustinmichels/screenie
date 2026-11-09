#!/usr/bin/env bash
# Replace /Applications/Screenie.app with the Release build, launch it, then delete build/.
# Expects `mise run build` to have run first (`mise run install` does that).
set -euo pipefail

cd "$(dirname "$0")/.."

APP=build/DerivedData/Build/Products/Release/Screenie.app
[ -d "$APP" ] || { echo "install: $APP not found; run 'mise run build' first" >&2; exit 1; }

scripts/quit.sh
# Delete the old copy rather than copying over it: cp -R merges bundles and breaks the signature.
rm -rf /Applications/Screenie.app
cp -R "$APP" /Applications/
open /Applications/Screenie.app
rm -rf build
