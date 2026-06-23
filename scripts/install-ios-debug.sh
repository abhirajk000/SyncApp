#!/usr/bin/env bash
# Build and install SyncBridge on a connected iPhone (Debug).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$ROOT/clients/ios"
DEVICE_ID="${1:-}"

command -v xcodegen >/dev/null || { echo "Install XcodeGen: brew install xcodegen" >&2; exit 1; }

cd "$IOS_DIR"
xcodegen generate

if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID=$(xcrun xctrace list devices 2>/dev/null | rg "iPhone" | rg -v Simulator | head -1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/' || true)
fi
if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID=$(xcrun devicectl list devices 2>/dev/null | rg "iPhone" | awk '{print $3}' | head -1 || true)
fi
if [[ -z "$DEVICE_ID" ]]; then
  echo "No iPhone found. Connect device and pass device id as first argument." >&2
  exit 1
fi

echo "==> Building for device $DEVICE_ID"
xcodebuild \
  -project SyncBridgeIOS.xcodeproj \
  -scheme SyncBridgeIOS \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath build/DerivedData \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-RMWSFGFGBJ}" \
  build

APP_PATH="$(find build/DerivedData/Build/Products/Debug-iphoneos -name 'SyncBridge.app' -type d | head -1)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "ERROR: SyncBridge.app not found after build" >&2
  exit 1
fi

echo "==> Installing $APP_PATH"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo "==> Launching"
xcrun devicectl device process launch --device "$DEVICE_ID" com.syncbridge.ios

echo ""
echo "Installed on device $DEVICE_ID"
