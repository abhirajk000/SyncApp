#!/usr/bin/env bash
# Install systemd units for SyncApp auto-start on reboot.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for unit in syncbridge syncbridge-boot syncbridge-monitor; do
  cp "$ROOT/scripts/systemd/${unit}.service" "/etc/systemd/system/${unit}.service"
  echo "  ✓ /etc/systemd/system/${unit}.service"
done

mkdir -p "$ROOT/logs"
systemctl daemon-reload
systemctl enable syncbridge syncbridge-boot syncbridge-monitor

echo ""
echo "✓ SyncApp systemd enabled:"
echo "  syncbridge         — docker compose up on boot (:2000 web, :2001 api)"
echo "  syncbridge-boot    — post-boot warmup + health check"
echo "  syncbridge-monitor — auto-recover every 60s"
echo ""
echo "Start now:  systemctl start syncbridge syncbridge-boot syncbridge-monitor"
echo "Status:     systemctl status syncbridge syncbridge-monitor"
