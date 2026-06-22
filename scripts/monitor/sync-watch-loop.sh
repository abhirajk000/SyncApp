#!/usr/bin/env bash
# Run sync-watch every 60s (systemd: syncbridge-monitor.service).
set -euo pipefail

SYNCAPP_ROOT="${SYNCAPP_ROOT:-/root/syncapp}"
INTERVAL="${SYNC_WATCH_INTERVAL_SEC:-60}"

while true; do
  bash "$SYNCAPP_ROOT/scripts/monitor/sync-watch.sh" >>"$SYNCAPP_ROOT/logs/sync-watch.log" 2>&1 || true
  sleep "$INTERVAL"
done
