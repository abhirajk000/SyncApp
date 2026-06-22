#!/usr/bin/env bash
# SyncApp VPS — deploy latest build (same pattern as K12Hunar deploy).
set -euo pipefail
# shellcheck source=lib.sh
source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/lib.sh"
sync_require_vps
sync_load_config
sync_colors

echo -e "${CYAN}▶ deploy-sync${NC}  $(date '+%Y-%m-%d %H:%M:%S')"
mkdir -p "$SYNCAPP_ROOT/logs"

if [[ -d "$SYNCAPP_ROOT/.git" ]]; then
  echo "  → git pull"
  git -C "$SYNCAPP_ROOT" pull --ff-only || git -C "$SYNCAPP_ROOT" pull
fi

echo "  → deploy"
export VITE_API_URL="${VITE_API_URL:-https://api.sync.abhiraj.xyz}"
bash "$SYNCAPP_ROOT/scripts/deploy-vps.sh" 2>&1 | tee -a "$SYNCAPP_ROOT/logs/deployment.log"

sync_mark_deploy

if systemctl is-enabled syncbridge-monitor.service >/dev/null 2>&1; then
  systemctl restart syncbridge-monitor 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}✓ deploy-sync done${NC}"
bash "$SYNCAPP_ROOT/scripts/vps/status.sh" || true
