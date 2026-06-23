#!/usr/bin/env bash
# Build and install SyncBridge release APK (real app: com.syncbridge.android).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_DIR="$ROOT/clients/android"
APK="$ANDROID_DIR/app/build/outputs/apk/release/app-release.apk"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
PKG="com.syncbridge.android"

if [[ ! -x "$ADB" ]]; then
  echo "adb not found at: $ADB"
  exit 1
fi

echo "==> Regenerating Android icons..."
python3 "$ROOT/scripts/make-android-icons.py" "$ROOT/icon.png"

echo "==> Building release APK..."
(cd "$ANDROID_DIR" && ./gradlew assembleRelease --no-daemon)

DEVICES=$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}')
if [[ -z "$DEVICES" ]]; then
  echo "No device connected."
  exit 1
fi

echo "==> Removing debug build (optional duplicate)..."
"$ADB" uninstall com.syncbridge.android.debug 2>/dev/null || true

echo "==> Installing release: $PKG"
"$ADB" install -r "$APK"

echo "==> Launching"
"$ADB" shell am start -n "$PKG/com.syncbridge.android.MainActivity"

echo ""
echo "Installed $PKG on: $DEVICES"
echo "Add to home: app drawer → SyncBridge → long-press → Add to Home"
