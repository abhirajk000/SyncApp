#!/usr/bin/env bash
# Build SyncBridge iOS IPA for device sideload (requires Apple code signing).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$ROOT/clients/ios"
OUT_DIR="$ROOT/releases/ios"
BUILD_DIR="$IOS_DIR/build"
APP_NAME="SyncBridge"
SCHEME="SyncBridgeIOS"
CONFIG="${1:-Release}"
TEAM_ID="${DEVELOPMENT_TEAM:-${APPLE_TEAM_ID:-RMWSFGFGBJ}}"

command -v xcodegen >/dev/null || { echo "Install XcodeGen: brew install xcodegen" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "Xcode command line tools required" >&2; exit 1; }

echo "==> Generate Xcode project"
cd "$IOS_DIR"
xcodegen generate

ARCHIVE_PATH="$BUILD_DIR/${APP_NAME}.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTS="$BUILD_DIR/ExportOptions.plist"
mkdir -p "$OUT_DIR" "$BUILD_DIR"

SIGN_ARGS=()
if [[ -n "$TEAM_ID" ]]; then
  echo "==> Using development team: $TEAM_ID"
  SIGN_ARGS+=(DEVELOPMENT_TEAM="$TEAM_ID" -allowProvisioningUpdates)
else
  echo "==> No DEVELOPMENT_TEAM set — trying automatic signing via Xcode account"
  SIGN_ARGS+=(-allowProvisioningUpdates)
fi

echo "==> Archive $SCHEME ($CONFIG)"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
xcodebuild \
  -project SyncBridgeIOS.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  "${SIGN_ARGS[@]}" \
  archive

cat > "$EXPORT_OPTS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>debugging</string>
  <key>compileBitcode</key>
  <false/>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>thinning</key>
  <string>&lt;none&gt;</string>
</dict>
</plist>
EOF

echo "==> Export IPA"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTS" \
  "${SIGN_ARGS[@]}"

IPA_SRC="$(find "$EXPORT_PATH" -name "*.ipa" | head -1)"
if [[ -z "$IPA_SRC" ]]; then
  echo "ERROR: IPA export failed" >&2
  exit 1
fi

IPA_DST="$OUT_DIR/${APP_NAME}-${CONFIG}.ipa"
cp "$IPA_SRC" "$IPA_DST"

echo ""
echo "Built: $IPA_DST"
echo ""
echo "Install on iPhone:"
echo "  • Xcode → Window → Devices and Simulators → drag IPA, or"
echo "  • Apple Configurator / AltStore / similar sideload tool"
