#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$IOS_DIR/Stub.xcodeproj"
SCHEME="Stub"
BUNDLE_ID="com.stub.life"
DERIVED_DATA="${TMPDIR:-/tmp}/stub-ios-derived-data"
QA_DIR="$IOS_DIR/qa"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Xcode is required. Install Xcode, select it with xcode-select, and retry." >&2
  exit 2
fi

SIMULATOR_ID="$({ xcrun simctl list devices booted --json; } | /usr/bin/python3 -c '
import json, sys
payload = json.load(sys.stdin)
booted = []
for runtime_devices in payload.get("devices", {}).values():
    for device in runtime_devices:
        if device.get("state") == "Booted" and device.get("isAvailable", True):
            booted.append(device)
for device in booted:
    if device.get("name") == "iPhone 16 Pro":
        print(device["udid"])
        raise SystemExit(0)
if booted:
    print(booted[0]["udid"])
    raise SystemExit(0)
raise SystemExit(1)
')"

if [[ -z "$SIMULATOR_ID" ]]; then
  echo "No booted iPhone Simulator was found. Boot one in Xcode and retry." >&2
  exit 3
fi

mkdir -p "$DERIVED_DATA" "$QA_DIR"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  ENABLE_DEBUG_DYLIB=NO \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Stub.app"
test -d "$APP_PATH"

xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"
xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" "$BUNDLE_ID"
sleep 2
xcrun simctl io "$SIMULATOR_ID" screenshot "$QA_DIR/home-launch.png"

echo "Stub built and launched on $SIMULATOR_ID."
echo "Launch screenshot: $QA_DIR/home-launch.png"
