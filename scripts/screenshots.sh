#!/usr/bin/env bash
# Screenshot tour of every screen in light and dark mode on an iOS simulator.
# Output: build/screenshots/*.png
#   scripts/screenshots.sh [simulator-udid]   (default: first booted iPhone)
set -euo pipefail
cd "$(dirname "$0")/.."
SIM="${1:-$(xcrun simctl list devices booted | grep -m1 -oE 'iPhone[^(]*\(([0-9A-F-]{36})\)' | grep -oE '[0-9A-F-]{36}')}"
[[ -n "$SIM" ]] || { echo "boot an iPhone simulator first" >&2; exit 1; }
rm -rf build/screenshots
for mode in light dark; do
  xcrun simctl ui "$SIM" appearance "$mode"
  flutter drive -d "$SIM" \
    --driver test_driver/screenshot_driver.dart \
    --target integration_test/screenshots_test.dart \
    --dart-define=SHOT_SUFFIX="$mode"
done
xcrun simctl ui "$SIM" appearance light
ls build/screenshots
