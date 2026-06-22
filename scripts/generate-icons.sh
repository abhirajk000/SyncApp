#!/usr/bin/env bash
# Regenerate platform icons from the root icon.png.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/icon.png"
WEB="$ROOT/clients/web/public"
ANDROID_RES="$ROOT/clients/android/app/src/main/res"
MACOS_RES="$ROOT/clients/macos/SyncBridgeMac/Resources"
IOS_ASSETS="$ROOT/clients/ios/Assets.xcassets"

if [[ ! -f "$SRC" ]]; then
  echo "Missing $SRC" >&2
  exit 1
fi

mkdir -p "$WEB" \
  "$ANDROID_RES/mipmap-mdpi" "$ANDROID_RES/mipmap-hdpi" "$ANDROID_RES/mipmap-xhdpi" \
  "$ANDROID_RES/mipmap-xxhdpi" "$ANDROID_RES/mipmap-xxxhdpi" "$ANDROID_RES/mipmap-anydpi-v26" \
  "$MACOS_RES/AppIcon.iconset" \
  "$IOS_ASSETS/AppIcon.appiconset" "$IOS_ASSETS/AppLogo.imageset"

cp "$SRC" "$WEB/icon.png"
sips -z 512 512 "$SRC" --out "$WEB/icon-512.png" >/dev/null
sips -z 192 192 "$SRC" --out "$WEB/icon-192.png" >/dev/null
sips -z 180 180 "$SRC" --out "$WEB/apple-touch-icon.png" >/dev/null
sips -z 32 32 "$SRC" --out "$WEB/favicon-32x32.png" >/dev/null
sips -z 16 16 "$SRC" --out "$WEB/favicon-16x16.png" >/dev/null
cp "$WEB/favicon-32x32.png" "$WEB/favicon.png"

sips -z 48 48 "$SRC" --out "$ANDROID_RES/mipmap-mdpi/ic_launcher.png" >/dev/null
sips -z 72 72 "$SRC" --out "$ANDROID_RES/mipmap-hdpi/ic_launcher.png" >/dev/null
sips -z 96 96 "$SRC" --out "$ANDROID_RES/mipmap-xhdpi/ic_launcher.png" >/dev/null
sips -z 144 144 "$SRC" --out "$ANDROID_RES/mipmap-xxhdpi/ic_launcher.png" >/dev/null
sips -z 192 192 "$SRC" --out "$ANDROID_RES/mipmap-xxxhdpi/ic_launcher.png" >/dev/null
sips -z 432 432 "$SRC" --out "$ANDROID_RES/drawable/ic_launcher_foreground.png" >/dev/null
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  cp "$ANDROID_RES/mipmap-xxxhdpi/ic_launcher.png" "$ANDROID_RES/mipmap-$d/ic_launcher_round.png" 2>/dev/null || true
done
cp "$ANDROID_RES/mipmap-mdpi/ic_launcher.png" "$ANDROID_RES/mipmap-mdpi/ic_launcher_round.png"
cp "$ANDROID_RES/mipmap-hdpi/ic_launcher.png" "$ANDROID_RES/mipmap-hdpi/ic_launcher_round.png"
cp "$ANDROID_RES/mipmap-xhdpi/ic_launcher.png" "$ANDROID_RES/mipmap-xhdpi/ic_launcher_round.png"
cp "$ANDROID_RES/mipmap-xxhdpi/ic_launcher.png" "$ANDROID_RES/mipmap-xxhdpi/ic_launcher_round.png"
cp "$ANDROID_RES/mipmap-xxxhdpi/ic_launcher.png" "$ANDROID_RES/mipmap-xxxhdpi/ic_launcher_round.png"

for spec in "16:icon_16x16.png" "32:icon_16x16@2x.png" "32:icon_32x32.png" "64:icon_32x32@2x.png" "128:icon_128x128.png" "256:icon_128x128@2x.png" "256:icon_256x256.png" "512:icon_256x256@2x.png" "512:icon_512x512.png" "1024:icon_512x512@2x.png"; do
  size="${spec%%:*}"; name="${spec##*:}"
  sips -z "$size" "$size" "$SRC" --out "$MACOS_RES/AppIcon.iconset/$name" >/dev/null
done
iconutil -c icns "$MACOS_RES/AppIcon.iconset" -o "$MACOS_RES/AppIcon.icns"
sips -z 22 22 "$SRC" --out "$MACOS_RES/MenuBarIcon.png" >/dev/null
sips -z 256 256 "$SRC" --out "$MACOS_RES/AppLogo.png" >/dev/null

sips -z 20 20 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-20.png" >/dev/null
sips -z 40 40 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-20@2x.png" >/dev/null
sips -z 60 60 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-20@3x.png" >/dev/null
sips -z 29 29 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-29.png" >/dev/null
sips -z 58 58 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-29@2x.png" >/dev/null
sips -z 87 87 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-29@3x.png" >/dev/null
sips -z 40 40 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-40.png" >/dev/null
sips -z 80 80 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-40@2x.png" >/dev/null
sips -z 120 120 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-40@3x.png" >/dev/null
sips -z 120 120 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-60@2x.png" >/dev/null
sips -z 180 180 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-60@3x.png" >/dev/null
sips -z 76 76 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-76.png" >/dev/null
sips -z 152 152 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-76@2x.png" >/dev/null
sips -z 167 167 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-83.5@2x.png" >/dev/null
sips -z 1024 1024 "$SRC" --out "$IOS_ASSETS/AppIcon.appiconset/icon-1024.png" >/dev/null
sips -z 128 128 "$SRC" --out "$IOS_ASSETS/AppLogo.imageset/AppLogo.png" >/dev/null
sips -z 256 256 "$SRC" --out "$IOS_ASSETS/AppLogo.imageset/AppLogo@2x.png" >/dev/null
sips -z 384 384 "$SRC" --out "$IOS_ASSETS/AppLogo.imageset/AppLogo@3x.png" >/dev/null

echo "Icons regenerated from $SRC"
