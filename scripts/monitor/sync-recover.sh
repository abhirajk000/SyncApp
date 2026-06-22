#!/usr/bin/env bash
# SyncApp auto-recovery — restart Docker stack components only.
set -euo pipefail

SYNCAPP_ROOT="${SYNCAPP_ROOT:-/root/syncapp}"
RECOVER_LOG="$SYNCAPP_ROOT/logs/auto-recover.log"
RECOVER_STATE="$SYNCAPP_ROOT/logs/sync-state"
COOLDOWN_SEC="${SYNC_RECOVER_COOLDOWN_SEC:-300}"

mkdir -p "$RECOVER_STATE" "$(dirname "$RECOVER_LOG")"

recover_log() {
  echo "[$(date -Iseconds)] $*" >>"$RECOVER_LOG"
}

recover_can_restart() {
  local key="$1"
  local now last=0 stamp="$RECOVER_STATE/recover_${key}"
  now="$(date +%s)"
  if [[ -f "$stamp" ]]; then
    last="$(cat "$stamp" 2>/dev/null || echo 0)"
    (( now - last < COOLDOWN_SEC )) && return 1
  fi
  return 0
}

recover_mark() {
  date +%s >"$RECOVER_STATE/recover_${1}"
}

recover_compose() {
  docker compose -f "$SYNCAPP_ROOT/docker-compose.vps.yml" -p syncbridge "$@"
}

recover_syncapp_stack() {
  recover_log "docker compose up -d"
  recover_compose up -d
  recover_mark "stack"
}

recover_api_only() {
  recover_log "restart api container"
  recover_compose restart api
  recover_mark "api"
}

recover_web_only() {
  recover_log "restart web container"
  recover_compose restart web
  recover_mark "web"
}
