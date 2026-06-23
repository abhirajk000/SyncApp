#!/usr/bin/env bash
# Build SyncBridge macOS app and install to /Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="SyncBridge"
INSTALL_PATH="/Applications/${APP_NAME}.app"

bash "$ROOT/scripts/build-macos-dmg.sh" "${1:-Release}"

APP_PATH="$(find "$ROOT/clients/macos/build/DerivedData/Build/Products" -name "${APP_NAME}.app" -type d | head -1)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "ERROR: built app not found" >&2
  exit 1
fi

echo "==> Quit running SyncBridge"
osascript -e 'tell application "SyncBridge" to quit' 2>/dev/null || true
pkill -x SyncBridge 2>/dev/null || true
sleep 1

echo "==> Install to $INSTALL_PATH"
rm -rf "$INSTALL_PATH"
ditto "$APP_PATH" "$INSTALL_PATH"

echo "==> Register icon"
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$INSTALL_PATH" >/dev/null 2>&1 || true
touch "$INSTALL_PATH"

echo ""
echo "Installed: $INSTALL_PATH"
echo "Open from menu bar icon, or run: open -a SyncBridge"
open -a "$INSTALL_PATH" || true
