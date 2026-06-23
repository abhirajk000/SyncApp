#!/usr/bin/env bash
# Build SyncBridge macOS menu bar app and package as a DMG.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MACOS_DIR="$ROOT/clients/macos"
OUT_DIR="$ROOT/releases/macos"
BUILD_DIR="$MACOS_DIR/build"
APP_NAME="SyncBridge"
SCHEME="SyncBridgeMac"
CONFIG="${1:-Release}"

command -v xcodegen >/dev/null || { echo "Install XcodeGen: brew install xcodegen" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "Xcode command line tools required" >&2; exit 1; }

echo "==> Generate platform icons"
bash "$ROOT/scripts/generate-icons.sh"

echo "==> Generate Xcode project"
cd "$MACOS_DIR"
xcodegen generate

echo "==> Build $SCHEME ($CONFIG)"
rm -rf "$BUILD_DIR/DerivedData"
xcodebuild \
  -project SyncBridgeMac.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  build

APP_PATH="$(find "$BUILD_DIR/DerivedData/Build/Products" -name "${APP_NAME}.app" -type d | head -1)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "ERROR: ${APP_NAME}.app not found after build" >&2
  exit 1
fi

echo "==> Register app icon with Launch Services"
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$APP_PATH" >/dev/null 2>&1 || true
touch "$APP_PATH"

echo "==> Package DMG"
mkdir -p "$OUT_DIR"
STAGE="$BUILD_DIR/dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -sf /Applications "$STAGE/Applications"

DMG_PATH="$OUT_DIR/${APP_NAME}-${CONFIG}.dmg"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo ""
echo "Built: $DMG_PATH"
echo "App:   $APP_PATH"
echo ""
echo "Install: open the DMG, drag SyncBridge to Applications."
echo "First launch: right-click → Open if macOS blocks unsigned apps."
