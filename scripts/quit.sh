#!/usr/bin/env bash
# Quit Screenie if it's running, and wait up to 5 s for it to exit.
set -euo pipefail

pgrep -xq Screenie || exit 0

osascript -e 'quit app id "com.dustinmichels.Screenie"'
i=0
while pgrep -xq Screenie; do
  i=$((i + 1))
  if [ "$i" -ge 50 ]; then
    echo "Screenie didn't quit; quit it and rerun." >&2
    exit 1
  fi
  sleep 0.1
done
