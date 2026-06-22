#!/usr/bin/env bash
# SyncApp health watch — probe and auto-recover (VPS only).
set -euo pipefail

SYNCAPP_ROOT="${SYNCAPP_ROOT:-/root/syncapp}"
# shellcheck source=../vps/lib.sh
source "$SYNCAPP_ROOT/scripts/vps/lib.sh"
# shellcheck source=sync-recover.sh
source "$SYNCAPP_ROOT/scripts/monitor/sync-recover.sh"

sync_load_config

api_down=0
web_down=0

if ! sync_api_ok; then
  api_down=1
fi
if ! sync_web_ok; then
  web_down=1
fi

if [[ "$api_down" -eq 0 && "$web_down" -eq 0 ]]; then
  exit 0
fi

recover_log "unhealthy: api=$api_down web=$web_down"

if ! sync_docker_ok; then
  recover_log "docker down — cannot recover SyncApp (not touching system docker)"
  exit 1
fi

if [[ "$api_down" -eq 1 && "$web_down" -eq 1 ]]; then
  if recover_can_restart stack; then
    recover_syncapp_stack
    sleep 15
  fi
elif [[ "$api_down" -eq 1 ]]; then
  if recover_can_restart api; then
    recover_api_only
    sleep 10
  fi
elif [[ "$web_down" -eq 1 ]]; then
  if recover_can_restart web; then
    recover_web_only
    sleep 5
  fi
fi

# Re-check
if sync_api_ok && sync_web_ok; then
  recover_log "recovered OK"
  exit 0
fi

recover_log "still unhealthy after recovery"
exit 1
