#!/usr/bin/env bash
# SyncApp VPS — LIVE/DOWN snapshot (matches K12Hunar style).
set -euo pipefail
# shellcheck source=lib.sh
source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/lib.sh"
sync_load_config
sync_colors

ok()   { echo -e "  ${GREEN}✓ LIVE${NC}  $*"; }
fail() { echo -e "  ${RED}✗ DOWN${NC}  $*"; }
warn() { echo -e "  ${YELLOW}⚠ WARN${NC}  $*"; }

_fail=0

echo -e "${CYAN}▶ SyncApp VPS status${NC}  $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

if sync_api_ok; then
  ms="$(sync_api_response_ms)"
  ok "SyncApp API     ${SYNC_API_LOCAL}/ready (${ms}ms)"
else
  fail "SyncApp API     ${SYNC_API_LOCAL}/ready"
  _fail=1
fi

if sync_web_ok; then
  ok "SyncApp Web     ${SYNC_WEB_LOCAL}/"
else
  fail "SyncApp Web     ${SYNC_WEB_LOCAL}/"
  _fail=1
fi

if sync_postgres_ok; then
  ok "PostgreSQL      (host :5432)"
else
  fail "PostgreSQL      (host :5432)"
  _fail=1
fi

if sync_nginx_ok; then
  ok "nginx"
else
  fail "nginx"
  _fail=1
fi

if sync_docker_ok; then
  ok "Docker"
else
  fail "Docker"
  _fail=1
fi

# WebSocket shares API port — ready implies WS endpoint available
if sync_api_ok; then
  ok "WebSocket       ${SYNC_API_DOMAIN}/ws"
else
  fail "WebSocket       ${SYNC_API_DOMAIN}/ws"
  _fail=1
fi

echo ""
echo -e "${CYAN}Resources${NC}"
mem_pct="$(free | awk '/Mem:/ {printf "%.0f", $3/$2*100}')"
disk_pct="$(df / | awk 'NR==2 {gsub(/%/,""); print $5}')"
echo -e "  Memory: ${mem_pct}%   Disk /: ${disk_pct}%"

echo ""
echo -e "${CYAN}Containers${NC}"
sync_compose ps 2>/dev/null | sed 's/^/  /' || warn "no containers"

echo ""
echo -e "${CYAN}Public${NC}"
pub_api="$(curl -sk --max-time 4 -o /dev/null -w '%{http_code}' "https://${SYNC_API_DOMAIN}/ready" 2>/dev/null || echo 000)"
pub_web="$(curl -sk --max-time 4 -o /dev/null -w '%{http_code}' "https://${SYNC_WEB_DOMAIN}/" 2>/dev/null || echo 000)"
if [[ "$pub_web" =~ ^(200|301|302|304)$ ]]; then
  ok "https://${SYNC_WEB_DOMAIN}/ ($pub_web)"
else
  fail "https://${SYNC_WEB_DOMAIN}/ ($pub_web)"
  _fail=1
fi
if [[ "$pub_api" == "200" ]]; then
  ok "https://${SYNC_API_DOMAIN}/ready"
else
  fail "https://${SYNC_API_DOMAIN}/ready ($pub_api)"
  _fail=1
fi

ssl_exp="$(sync_ssl_expiry)"
if [[ "$ssl_exp" == "no certificate" ]]; then
  warn "SSL — no certificate (HTTP only)"
else
  ok "SSL expires $ssl_exp"
fi

echo ""
if [[ "$_fail" -eq 0 ]]; then
  echo -e "${GREEN}✓ All SyncApp services live${NC}"
  exit 0
fi
echo -e "${RED}✗ Some services failed — try: restart-sync  or  deploy-sync${NC}"
exit 1
