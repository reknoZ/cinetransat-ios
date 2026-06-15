#!/usr/bin/env bash
# Capture App Store screenshots from the iOS Simulator.
# Requires Xcode and a bootable simulator runtime.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUNDLE_ID="com.heewhack.CineTransat"
OUT_DIR="$ROOT/AppStoreScreenshots"
IPHONE_DEVICE="${IPHONE_DEVICE:-iPhone 17 Pro Max}"
IPAD_DEVICE="${IPAD_DEVICE:-iPad Pro 13-inch (M5)}"
CAPTURE_IPAD="${CAPTURE_IPAD:-1}"

SCHEME="$(xcodebuild -list -json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['project']['schemes'][0])")"

capture_device() {
  local device_name="$1"
  local out_subdir="$2"
  shift 2
  local pages=("$@")

  echo "==> Building for simulator: $device_name"
  xcodebuild \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=${device_name}" \
    -derivedDataPath "$ROOT/.derivedDataScreenshots" \
    CODE_SIGNING_ALLOWED=NO \
    build >/dev/null

  local app_path
  app_path="$(find "$ROOT/.derivedDataScreenshots/Build/Products" -name 'CinéTransat.app' -o -name 'CinéTransat.app' | head -1)"
  if [[ -z "$app_path" ]]; then
    echo "Could not find built .app bundle." >&2
    exit 1
  fi

  local udid
  udid="$(xcrun simctl list devices available -j | python3 -c "
import json, sys
name = sys.argv[1]
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if 'iOS' not in runtime and 'iOS' not in runtime.replace('-', ' '):
        continue
    for d in devices:
        if d.get('name') == name and d.get('isAvailable'):
            print(d['udid'])
            raise SystemExit
raise SystemExit('Simulator not found: ' + name)
" "$device_name")"

  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b

  xcrun simctl uninstall "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$udid" "$app_path"

  mkdir -p "$OUT_DIR/$out_subdir"

  xcrun simctl status_bar "$udid" override \
    --time "9:41" \
    --dataNetwork wifi \
    --wifiBars 3 \
    --cellularMode active \
    --cellularBars 4 \
    --batteryState charged \
    --batteryLevel 100

  for page in "${pages[@]}"; do
    echo "    Capturing $out_subdir/$page.png"
    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$udid" "$BUNDLE_ID" -AppStoreScreenshots -ScreenshotPage "$page" >/dev/null
    sleep 2.5
    xcrun simctl io "$udid" screenshot "$OUT_DIR/$out_subdir/${page}.png"
  done

  xcrun simctl status_bar "$udid" clear >/dev/null 2>&1 || true
}

PAGES=(program detail watchlist info settings)

capture_device "$IPHONE_DEVICE" "iPhone-6.9" "${PAGES[@]}"

if [[ "$CAPTURE_IPAD" == "1" ]]; then
  capture_device "$IPAD_DEVICE" "iPad-13" "${PAGES[@]}"
fi

echo ""
echo "Screenshots saved under: $OUT_DIR"
echo "Upload the iPhone-6.9 set to App Store Connect (6.9\" display class)."
echo "iPad-13 is included because CinéTransat is a universal app."
