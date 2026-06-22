#!/usr/bin/env bash
# SyncApp VPS — show deployment info.
set -euo pipefail
# shellcheck source=lib.sh
source "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)/lib.sh"
sync_load_config
sync_colors

echo -e "${CYAN}▶ SyncApp information${NC}  $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
printf "  ${CYAN}%-22s${NC} %s\n" "Web domain" "$SYNC_WEB_DOMAIN"
printf "  ${CYAN}%-22s${NC} %s\n" "API domain" "$SYNC_API_DOMAIN"
printf "  ${CYAN}%-22s${NC} %s\n" "Local web port" "127.0.0.1:2000"
printf "  ${CYAN}%-22s${NC} %s\n" "Local API port" "127.0.0.1:2001"
echo ""

if sync_docker_ok; then
  printf "  ${CYAN}%-22s${NC} ${GREEN}running${NC}\n" "Docker"
else
  printf "  ${CYAN}%-22s${NC} ${RED}stopped${NC}\n" "Docker"
fi

echo -e "  ${CYAN}Containers${NC}"
sync_compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null \
  | sed 's/^/    /' || echo "    (none)"

echo ""
printf "  ${CYAN}%-22s${NC} %s\n" "Database" "$SYNC_DB_NAME"
printf "  ${CYAN}%-22s${NC} %s\n" "DB user" "$SYNC_DB_USER"
printf "  ${CYAN}%-22s${NC} %s\n" "Storage path" "$SYNC_STORAGE_PATH"
echo ""

ssl_exp="$(sync_ssl_expiry)"
if [[ "$ssl_exp" == "no certificate" ]]; then
  printf "  ${CYAN}%-22s${NC} ${YELLOW}HTTP only (no cert)${NC}\n" "SSL"
else
  printf "  ${CYAN}%-22s${NC} %s\n" "SSL expiry" "$ssl_exp"
fi

printf "  ${CYAN}%-22s${NC} %s\n" "Last deployment" "$(sync_last_deploy)"
printf "  ${CYAN}%-22s${NC} %s\n" "SyncApp version" "$(sync_version)"
echo ""

mem="$(free -h | awk '/Mem:/ {print $3 " / " $2 " (" int($3/$2*100+0.5) "% used)"}')"
disk="$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 " used)"}')"
printf "  ${CYAN}%-22s${NC} %s\n" "RAM" "$mem"
printf "  ${CYAN}%-22s${NC} %s\n" "Disk /" "$disk"
echo ""
echo -e "  ${DIM}Commands: status-sync  logs-sync  restart-sync  deploy-sync  health-sync${NC}"
