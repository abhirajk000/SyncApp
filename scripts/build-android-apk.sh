#!/usr/bin/env bash
# Build SyncBridge Android release APK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_DIR="$ROOT/clients/android"
OUT_DIR="$ROOT/releases/android"

echo "==> Build release APK"
cd "$ANDROID_DIR"
./gradlew assembleRelease --no-daemon

mkdir -p "$OUT_DIR"
cp -f app/build/outputs/apk/release/app-release.apk "$OUT_DIR/SyncBridge-release.apk"
cp -f app/build/outputs/apk/debug/app-debug.apk "$OUT_DIR/SyncBridge-debug.apk" 2>/dev/null || \
  ./gradlew assembleDebug --no-daemon && cp -f app/build/outputs/apk/debug/app-debug.apk "$OUT_DIR/SyncBridge-debug.apk"

echo ""
echo "Built: $OUT_DIR/SyncBridge-release.apk"
ls -lh "$OUT_DIR/SyncBridge-release.apk"
