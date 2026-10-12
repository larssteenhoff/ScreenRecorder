#!/bin/bash
# Builds Screen Recorder in Release, assembles "build/Screen Recorder.app" and signs it.
# Signing identity: $SIGN_IDENTITY, else the first Developer ID / Apple Development
# identity in the keychain, else ad hoc ("-"). A stable identity keeps the macOS
# Screen Recording permission valid across rebuilds; an ad hoc signature does not.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/Screen Recorder.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/ScreenRecorder" "$APP/Contents/MacOS/ScreenRecorder"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application|Apple Development/ {print $2; exit}')}"
IDENTITY="${IDENTITY:--}"

codesign --force --options runtime --timestamp=none \
    --entitlements "Resources/ScreenRecorder.entitlements" \
    --sign "$IDENTITY" "$APP"

echo "Built $APP (signed with: $IDENTITY)"
