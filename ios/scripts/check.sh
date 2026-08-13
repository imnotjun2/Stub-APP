#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$IOS_DIR/.." && pwd)"
MODULE_CACHE="${TMPDIR:-/tmp}/stub-swift-module-cache"

mkdir -p "$MODULE_CACHE"

plutil -lint "$IOS_DIR/Stub.xcodeproj/project.pbxproj"
xmllint --noout "$IOS_DIR/Stub.xcodeproj/xcshareddata/xcschemes/Stub.xcscheme"
swiftc -frontend -parse "$IOS_DIR"/Stub/*.swift

MAC_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
if [[ -d "$MAC_SDK" ]]; then
  swiftc \
    -typecheck \
    -parse-as-library \
    -D STATIC_CHECK \
    -sdk "$MAC_SDK" \
    -module-cache-path "$MODULE_CACHE" \
    "$IOS_DIR"/Stub/*.swift

  swiftc \
    -parse-as-library \
    -D STATIC_CHECK \
    -sdk "$MAC_SDK" \
    -module-cache-path "$MODULE_CACHE" \
    "$IOS_DIR"/Stub/*.swift \
    -o "${TMPDIR:-/tmp}/stub-native-link-check"

  CONTRACT_BINARY="${TMPDIR:-/tmp}/stub-archive-store-contract"
  swiftc \
    -parse-as-library \
    -D STATIC_CHECK \
    -sdk "$MAC_SDK" \
    -module-cache-path "$MODULE_CACHE" \
    "$IOS_DIR/Stub/Models.swift" \
    "$IOS_DIR/Stub/ArchiveStore.swift" \
    "$IOS_DIR/Tests/ArchiveStoreContract.swift" \
    -o "$CONTRACT_BINARY"
  "$CONTRACT_BINARY"
fi

if rg -n "WKWebView|SFSafariViewController|WebView\(" "$IOS_DIR/Stub" --glob '*.swift'; then
  echo "A web wrapper was found in the native target." >&2
  exit 1
fi

for asset in \
  movie-ticket.png boarding-pass.png train-ticket.png movie-poster.jpg ramen.jpg \
  trip-map.png airline-mu.png airline-ca.png airline-cz.png; do
  test -s "$IOS_DIR/Stub/Resources/$asset"
done

test "$(sips -g pixelWidth "$IOS_DIR/Stub/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" | awk '/pixelWidth/ {print $2}')" = "1024"
test "$(sips -g pixelHeight "$IOS_DIR/Stub/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" | awk '/pixelHeight/ {print $2}')" = "1024"

test "$(rg -l "struct HomeView" "$IOS_DIR/Stub/HomeView.swift" | wc -l | tr -d ' ')" = "1"
test "$(rg -l "struct TripsView" "$IOS_DIR/Stub/TripsView.swift" | wc -l | tr -d ' ')" = "1"
test "$(rg -l "struct WallView" "$IOS_DIR/Stub/WallView.swift" | wc -l | tr -d ' ')" = "1"
test "$(rg -l "struct ProfileView" "$IOS_DIR/Stub/ProfileView.swift" | wc -l | tr -d ' ')" = "1"
test "$(rg -l "PhotosPicker" "$IOS_DIR/Stub/StubEditorView.swift" | wc -l | tr -d ' ')" = "1"
test "$(rg -l "TripPlacement" "$IOS_DIR/Stub/Models.swift" | wc -l | tr -d ' ')" = "1"

echo "Stub iOS static checks passed."
