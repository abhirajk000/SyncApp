#!/usr/bin/env bash
# Build SyncBridge web client and export static files.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB_DIR="$ROOT/clients/web"
OUT_DIR="$ROOT/releases/web"
VITE_API_URL="${VITE_API_URL:-https://sync.abhiraj.xyz}"

echo "==> Build web (VITE_API_URL=$VITE_API_URL)"
cd "$WEB_DIR"
npm ci --silent 2>/dev/null || npm install --silent
VITE_API_URL="$VITE_API_URL" npm run build

echo "==> Export to $OUT_DIR"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
cp -R dist/* "$OUT_DIR/"

# Convenience archive for deployment
ARCHIVE="$ROOT/releases/SyncBridge-web.tar.gz"
tar -czf "$ARCHIVE" -C "$OUT_DIR" .
echo ""
echo "Built: $OUT_DIR/"
echo "Archive: $ARCHIVE"
du -sh "$OUT_DIR" "$ARCHIVE"
