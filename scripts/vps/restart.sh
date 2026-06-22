#!/usr/bin/env bash
# SyncApp VPS — restart SyncApp containers only (not K12Hunar / postgres / nginx).
set -euo pipefail
# shellcheck source=lib.sh
source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/lib.sh"
sync_require_vps
sync_load_config
sync_colors

echo -e "${CYAN}▶ restart-sync${NC}  $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Restarting SyncApp Docker stack only…"
echo ""

sync_compose restart

echo "  Waiting for API…"
for i in $(seq 1 20); do
  if sync_api_ok; then
    echo -e "${GREEN}✓ API ready${NC}"
    break
  fi
  sleep 2
done

if ! sync_api_ok; then
  echo -e "${RED}✗ API not ready — run: health-sync${NC}" >&2
  exit 1
fi

echo ""
bash "$SYNCAPP_ROOT/scripts/vps/status.sh" || true
