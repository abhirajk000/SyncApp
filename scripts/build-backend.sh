#!/usr/bin/env bash
# Build SyncBridge Go API binary for Linux VPS (amd64).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/releases/backend"
BINARY="$OUT_DIR/syncbridge-api-linux-amd64"

mkdir -p "$OUT_DIR"

VERSION="$(git -C "$ROOT" describe --tags --always --dirty 2>/dev/null || echo "dev")"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

echo "==> Build API binary ($VERSION)"
cd "$ROOT"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
  -ldflags="-w -s -X main.version=${VERSION} -X main.commit=${COMMIT} -X main.buildDate=${BUILD_DATE}" \
  -o "$BINARY" \
  ./cmd/api

chmod +x "$BINARY"
echo ""
echo "Built: $BINARY"
ls -lh "$BINARY"
