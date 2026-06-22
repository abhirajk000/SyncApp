#!/usr/bin/env bash
# One-shot VPS boot: ensure SyncApp stack is up after reboot.
set -euo pipefail

SYNCAPP_ROOT="${SYNCAPP_ROOT:-/root/syncapp}"
# shellcheck source=../vps/lib.sh
source "$SYNCAPP_ROOT/scripts/vps/lib.sh"
sync_load_config

mkdir -p "$SYNCAPP_ROOT/logs"

recover_log() {
  echo "[$(date -Iseconds)] boot: $*" >>"$SYNCAPP_ROOT/logs/sync-watch.log"
}

recover_log "vps boot warmup"

# Wait for Docker + PostgreSQL
for i in $(seq 1 30); do
  sync_docker_ok && sync_postgres_ok && break
  sleep 2
done

sleep "${SYNC_BOOT_WARMUP_SEC:-10}"

recover_log "docker compose up -d"
sync_compose up -d

for i in $(seq 1 30); do
  if sync_api_ok && sync_web_ok; then
    recover_log "boot OK — api + web ready"
    exit 0
  fi
  sleep 2
done

recover_log "boot WARN — services not ready after warmup"
exit 1
