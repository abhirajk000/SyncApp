#!/bin/sh
set -e

STORAGE_PATH="${OBJECT_STORAGE_PATH:-/opt/syncbridge/storage}"
if [ -d "$STORAGE_PATH" ] || mkdir -p "$STORAGE_PATH" 2>/dev/null; then
  chown -R syncbridge:syncbridge "$STORAGE_PATH" 2>/dev/null || true
fi

exec su-exec syncbridge:syncbridge ./api "$@"
