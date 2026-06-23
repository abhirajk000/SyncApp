#!/usr/bin/env bash
# Build (if needed) and install SyncBridge debug APK on a USB-connected device.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_DIR="$ROOT/clients/android"
APK="$ANDROID_DIR/app/build/outputs/apk/debug/app-debug.apk"
ADB="${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb"
PKG="com.syncbridge.android.debug"

if [[ ! -x "$ADB" ]]; then
  echo "adb not found at: $ADB"
  echo "Install Android platform-tools or set ANDROID_HOME."
  exit 1
fi

if [[ ! -f "$APK" ]]; then
  echo "==> Building debug APK..."
  (cd "$ANDROID_DIR" && ./gradlew assembleDebug --no-daemon)
fi

echo "==> Checking device..."
DEVICES=$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}')
if [[ -z "$DEVICES" ]]; then
  echo ""
  echo "No authorized device found."
  echo "1. On phone: Settings → Developer options → USB debugging ON"
  echo "2. Connect USB cable (data-capable, not charge-only)"
  echo "3. Tap 'Allow USB debugging' on the phone prompt"
  echo "4. Re-run: $0"
  exit 1
fi

echo "==> Installing $APK"
"$ADB" install -r "$APK"

echo "==> Launching app"
"$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || \
  "$ADB" shell am start -n "$PKG/com.syncbridge.android.MainActivity"

echo ""
echo "Installed and launched on: $DEVICES"
