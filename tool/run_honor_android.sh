#!/usr/bin/env bash
set -euo pipefail

DEVICE_ID="${1:-ASUDJV5827H08319}"
FLUTTER_BIN="${FLUTTER_BIN:-/Users/macbookair/development/flutter/bin/flutter}"
APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
PACKAGE_NAME="com.highest.camera.apex_camera"
ACTIVITY_NAME="$PACKAGE_NAME/.MainActivity"

"$FLUTTER_BIN" build apk --debug
adb -s "$DEVICE_ID" install -t -r -d --no-streaming "$APK_PATH"
adb -s "$DEVICE_ID" shell am force-stop "$PACKAGE_NAME"
adb -s "$DEVICE_ID" shell am start -n "$ACTIVITY_NAME"

echo "App installed without streaming and launched on $DEVICE_ID."
echo "For hot reload/debugging, use: $FLUTTER_BIN attach -d $DEVICE_ID"
