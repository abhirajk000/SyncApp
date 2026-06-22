#!/usr/bin/env bash
# Run ON VPS once: install SyncApp commands to /usr/local/bin + ~/.bashrc
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKER="# syncapp-shell-aliases"
STATUS_MARKER="# syncapp-shell-status"
BASHRC="${HOME}/.bashrc"

chmod +x "$ROOT"/scripts/vps/*.sh 2>/dev/null || true
chmod +x "$ROOT"/scripts/monitor/*.sh 2>/dev/null || true
chmod +x "$ROOT"/scripts/vps-install-systemd.sh 2>/dev/null || true
chmod +x "$ROOT"/scripts/deploy-vps.sh 2>/dev/null || true

mkdir -p "$ROOT/logs"

# Install wrapper scripts (symlinks break BASH_SOURCE paths)
install_cmd() {
  local name="$1" src="$2"
  rm -f "/usr/local/bin/$name"
  cat >"/usr/local/bin/$name" <<EOF
#!/usr/bin/env bash
exec bash "$src" "\$@"
EOF
  chmod +x "/usr/local/bin/$name" "$src"
  echo "  ✓ /usr/local/bin/$name"
}

install_cmd info-sync    "$ROOT/scripts/vps/info.sh"
install_cmd status-sync  "$ROOT/scripts/vps/status.sh"
install_cmd logs-sync    "$ROOT/scripts/vps/logs.sh"
install_cmd restart-sync "$ROOT/scripts/vps/restart.sh"
install_cmd deploy-sync  "$ROOT/scripts/vps/deploy.sh"
install_cmd health-sync  "$ROOT/scripts/vps/health.sh"

if ! grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
  cat >>"$BASHRC" <<EOF

$MARKER
[[ -f $ROOT/scripts/vps-shell-aliases.sh ]] && source $ROOT/scripts/vps-shell-aliases.sh
EOF
fi

if ! grep -q "$STATUS_MARKER" "$BASHRC" 2>/dev/null; then
  cat >>"$BASHRC" <<'EOF'

# syncapp-shell-status
echo "📋 SyncApp Status"
echo "──────────────────────────────────────────────"
if [[ -f /root/syncapp/scripts/vps-shell-status-sync.sh ]]; then
  # shellcheck source=/dev/null
  source /root/syncapp/scripts/vps-shell-status-sync.sh
fi
echo "──────────────────────────────────────────────"
EOF
fi

echo ""
echo "✓ SyncApp commands installed — open a new SSH session, then:"
echo ""
echo "  info-sync       deployment info"
echo "  status-sync     LIVE/DOWN snapshot"
echo "  logs-sync       API + Docker logs"
echo "  restart-sync    restart SyncApp containers only"
echo "  deploy-sync     pull + rebuild + deploy"
echo "  health-sync     full diagnostics"
echo ""
echo "  systemd: bash $ROOT/scripts/vps-install-systemd.sh"
