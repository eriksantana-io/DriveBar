#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
swift build -c release --disable-sandbox --scratch-path .build -debug-info-format none
BIN="$(swift build -c release --disable-sandbox --scratch-path .build -debug-info-format none --show-bin-path)"
APP="$PWD/dist/DriveBar.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN/DriveBar" "$APP/Contents/MacOS/DriveBar"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Info.plist "$APP/Contents/Info.plist"
if [[ -n "${DRIVEBAR_SIGNING_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$DRIVEBAR_SIGNING_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
codesign --verify --deep --strict "$APP"
echo "Built: $APP"
