#!/usr/bin/env bash
# SyncApp VPS — recent logs and errors.
set -euo pipefail
# shellcheck source=lib.sh
source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/lib.sh"
sync_load_config
sync_colors

LINES="${1:-80}"

echo -e "${CYAN}▶ SyncApp logs${NC}  (last ${LINES} lines)"
echo ""

echo -e "${CYAN}── API (syncbridge-api) ──${NC}"
sync_compose logs --tail="$LINES" api 2>/dev/null || echo "  (no api logs)"

echo ""
echo -e "${CYAN}── Web (syncbridge-web) ──${NC}"
sync_compose logs --tail="$LINES" web 2>/dev/null || echo "  (no web logs)"

echo ""
echo -e "${CYAN}── Recent errors (API) ──${NC}"
sync_compose logs --tail=500 api 2>/dev/null \
  | grep -iE 'error|fatal|panic|failed' | tail -20 || echo "  (none)"

echo ""
echo -e "${CYAN}── Monitor / recovery ──${NC}"
for f in "$SYNCAPP_ROOT/logs/sync-watch.log" "$SYNCAPP_ROOT/logs/auto-recover.log" "$SYNCAPP_ROOT/logs/deployment.log"; do
  if [[ -f "$f" ]]; then
    echo -e "  ${DIM}$(basename "$f")${NC}"
    tail -10 "$f" | sed 's/^/    /'
  fi
done

echo ""
echo -e "${DIM}Follow live: docker compose -f $SYNC_COMPOSE_FILE -p $SYNC_COMPOSE_PROJECT logs -f api${NC}"
