#!/usr/bin/env bash
# SyncApp VPS — comprehensive diagnostics.
set -euo pipefail
# shellcheck source=lib.sh
source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/lib.sh"
sync_load_config
sync_colors

fail=0
section() { echo ""; echo -e "${CYAN}── $* ──${NC}"; }
pass() { echo -e "  ${GREEN}✓${NC} $*"; }
bad()  { echo -e "  ${RED}✗${NC} $*"; fail=1; }
note() { echo -e "  ${YELLOW}⚠${NC} $*"; }

section "API"
if sync_api_ok; then
  pass "GET ${SYNC_API_LOCAL}/ready"
  pass "Response time: $(sync_api_response_ms)ms"
else
  bad "GET ${SYNC_API_LOCAL}/ready"
fi

health="$(curl -sf --max-time 5 "${SYNC_API_LOCAL}/health" 2>/dev/null || echo fail)"
[[ "$health" == *ok* ]] && pass "/health" || bad "/health"

section "Web"
if sync_web_ok; then
  pass "GET ${SYNC_WEB_LOCAL}/"
else
  bad "GET ${SYNC_WEB_LOCAL}/"
fi

section "WebSocket"
if sync_api_ok; then
  pass "WS endpoint on ${SYNC_API_LOCAL}/ws (same port as API)"
else
  bad "WS unavailable (API down)"
fi

section "Database"
if sync_postgres_ok; then
  pass "PostgreSQL service active"
else
  bad "PostgreSQL service"
fi
if sync_db_ok; then
  pass "Connect ${SYNC_DB_USER}@${SYNC_DB_NAME}"
else
  bad "Connect ${SYNC_DB_USER}@${SYNC_DB_NAME}"
fi

section "Docker"
if sync_docker_ok; then
  pass "Docker daemon"
else
  bad "Docker daemon"
fi
sync_compose ps 2>/dev/null | sed 's/^/  /' || bad "compose ps failed"

section "Storage"
vol_path="$(docker volume inspect syncbridge_syncbridge_storage --format '{{.Mountpoint}}' 2>/dev/null || echo '')"
if [[ -n "$vol_path" && -d "$vol_path" ]]; then
  pass "Docker volume mounted at $vol_path"
  du -sh "$vol_path" 2>/dev/null | sed 's/^/  /' || true
else
  note "Storage volume inspect skipped"
fi

section "DNS"
for host in "$SYNC_WEB_DOMAIN" "$SYNC_API_DOMAIN"; do
  ips="$(dig +short "$host" A 2>/dev/null | tr '\n' ' ')"
  if [[ -n "$ips" ]]; then
    pass "$host → $ips"
  else
    note "$host — no A record"
  fi
done

section "SSL"
ssl_exp="$(sync_ssl_expiry)"
if [[ "$ssl_exp" == "no certificate" ]]; then
  note "No Let's Encrypt cert — using HTTP nginx config"
else
  pass "Certificate expires: $ssl_exp"
fi

section "Public endpoints"
pub_api="$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://${SYNC_API_DOMAIN}/ready" 2>/dev/null || echo 000)"
pub_web="$(curl -sk --max-time 10 -o /dev/null -w '%{http_code}' "https://${SYNC_WEB_DOMAIN}/" 2>/dev/null || echo 000)"
[[ "$pub_api" == "200" ]] && pass "https://${SYNC_API_DOMAIN}/ready" || note "https://${SYNC_API_DOMAIN}/ready ($pub_api)"
[[ "$pub_web" =~ ^(200|301|302|304)$ ]] && pass "https://${SYNC_WEB_DOMAIN}/" || note "https://${SYNC_WEB_DOMAIN}/ ($pub_web)"

echo ""
if [[ "$fail" -eq 0 ]]; then
  echo -e "${GREEN}✓ health-sync: all critical checks passed${NC}"
  exit 0
fi
echo -e "${RED}✗ health-sync: some checks failed${NC}"
exit 1
