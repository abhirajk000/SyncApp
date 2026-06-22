#!/usr/bin/env bash
# Shared helpers for SyncApp VPS commands.
set -euo pipefail

sync_root() {
  if [[ -n "${SYNCAPP_ROOT:-}" && -d "${SYNCAPP_ROOT}/scripts" ]]; then
    printf '%s\n' "$SYNCAPP_ROOT"
    return
  fi
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -d "$lib_dir/../../scripts/vps" ]]; then
    cd "$lib_dir/../.." && pwd
    return
  fi
  printf '%s\n' /root/syncapp
}

sync_is_vps() {
  [[ "${SYNCAPP_ENV:-}" == "vps" ]] && return 0
  local root
  root="$(sync_root)"
  [[ "$(readlink -f "$root" 2>/dev/null)" == "$(readlink -f /root/syncapp 2>/dev/null || echo __none__)" ]] && return 0
  [[ "$(readlink -f "$root" 2>/dev/null)" == "$(readlink -f /opt/syncapp 2>/dev/null || echo __none2__)" ]] && return 0
  [[ -f /etc/nginx/sites-enabled/syncbridge ]] && return 0
  return 1
}

sync_require_vps() {
  if ! sync_is_vps; then
    echo "This command is for the production VPS only." >&2
    exit 1
  fi
}

sync_export_root() {
  export SYNCAPP_ROOT="$(sync_root)"
  export SYNCAPP_ENV="${SYNCAPP_ENV:-vps}"
  cd "$SYNCAPP_ROOT"
}

# ── Config (override in config/syncapp-vps.env) ─────────────────────────────
sync_load_config() {
  sync_export_root
  # shellcheck disable=SC1091
  [[ -f "$SYNCAPP_ROOT/config/syncapp-vps.env" ]] && source "$SYNCAPP_ROOT/config/syncapp-vps.env"
  export SYNC_WEB_DOMAIN="${SYNC_WEB_DOMAIN:-sync.abhiraj.xyz}"
  export SYNC_API_DOMAIN="${SYNC_API_DOMAIN:-api.sync.abhiraj.xyz}"
  export SYNC_WEB_LOCAL="${SYNC_WEB_LOCAL:-http://127.0.0.1:2000}"
  export SYNC_API_LOCAL="${SYNC_API_LOCAL:-http://127.0.0.1:2001}"
  export SYNC_DB_NAME="${SYNC_DB_NAME:-syncbridge}"
  export SYNC_DB_USER="${SYNC_DB_USER:-syncbridge_user}"
  export SYNC_STORAGE_PATH="${SYNC_STORAGE_PATH:-/opt/syncbridge/storage}"
  export SYNC_COMPOSE_FILE="${SYNC_COMPOSE_FILE:-docker-compose.vps.yml}"
  export SYNC_COMPOSE_PROJECT="${SYNC_COMPOSE_PROJECT:-syncbridge}"
}

sync_compose() {
  docker compose -f "$SYNCAPP_ROOT/$SYNC_COMPOSE_FILE" -p "$SYNC_COMPOSE_PROJECT" "$@"
}

sync_colors() {
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  DIM='\033[2m'
  NC='\033[0m'
}

sync_api_ok() {
  local resp
  resp="$(curl -sf --max-time 5 "${SYNC_API_LOCAL}/ready" 2>/dev/null)" || return 1
  printf '%s' "$resp" | grep -q '"status":"ready"'
}

sync_web_ok() {
  curl -sfI --max-time 5 "${SYNC_WEB_LOCAL}/" >/dev/null 2>&1
}

sync_docker_ok() {
  systemctl is-active --quiet docker 2>/dev/null || pgrep -x dockerd >/dev/null 2>&1
}

sync_nginx_ok() {
  systemctl is-active --quiet nginx 2>/dev/null
}

sync_postgres_ok() {
  systemctl is-active --quiet postgresql 2>/dev/null
}

sync_db_ok() {
  local pass_file="$SYNCAPP_ROOT/.db_password"
  [[ -f "$pass_file" ]] || return 1
  PGPASSWORD="$(cat "$pass_file")" psql -h 127.0.0.1 -U "$SYNC_DB_USER" -d "$SYNC_DB_NAME" -c "SELECT 1" >/dev/null 2>&1
}

sync_ssl_expiry() {
  local cert="/etc/letsencrypt/live/${SYNC_WEB_DOMAIN}/fullchain.pem"
  if [[ -f "$cert" ]]; then
    openssl x509 -enddate -noout -in "$cert" 2>/dev/null | sed 's/notAfter=//'
  else
    echo "no certificate"
  fi
}

sync_version() {
  curl -sf --max-time 3 "${SYNC_API_LOCAL}/version" 2>/dev/null \
    | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4 \
    || echo "unknown"
}

sync_last_deploy() {
  local f="$SYNCAPP_ROOT/logs/deployment.log"
  if [[ -f "$f" ]]; then
    tail -1 "$f" 2>/dev/null || echo "unknown"
  elif [[ -f "$SYNCAPP_ROOT/.deployed_at" ]]; then
    cat "$SYNCAPP_ROOT/.deployed_at"
  else
    echo "never"
  fi
}

sync_mark_deploy() {
  mkdir -p "$SYNCAPP_ROOT/logs"
  date -Iseconds >"$SYNCAPP_ROOT/.deployed_at"
  echo "$(date -Iseconds) deploy-sync completed" >>"$SYNCAPP_ROOT/logs/deployment.log"
}

sync_api_response_ms() {
  local t
  t="$(curl -sf -o /dev/null -w '%{time_total}' --max-time 10 "${SYNC_API_LOCAL}/health" 2>/dev/null || echo 0)"
  awk -v t="$t" 'BEGIN { printf "%.0f", t * 1000 }'
}
