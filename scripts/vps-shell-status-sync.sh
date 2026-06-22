#!/usr/bin/env bash
# Compact SyncApp lines for SSH login banner (sourced from ~/.bashrc).
SYNC_ROOT="${SYNCAPP_ROOT:-/root/syncapp}"
if [[ -x "$SYNC_ROOT/scripts/vps/status.sh" ]]; then
  bash "$SYNC_ROOT/scripts/vps/status.sh" 2>/dev/null | sed -n '1,6p' | sed 's/^/  /' || true
fi
