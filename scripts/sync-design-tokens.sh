#!/usr/bin/env bash
# Validates shared/theme/tokens.json and reports platform mapping.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOKENS="$ROOT/shared/theme/tokens.json"

echo "SyncBridge Design Token Sync"
echo "=============================="
echo "Canonical: shared/theme/tokens.json"
echo ""

if [[ ! -f "$TOKENS" ]]; then
  echo "ERROR: tokens.json not found at $TOKENS" >&2
  exit 1
fi

export ROOT
python3 <<'PY'
import json, os, sys
from pathlib import Path

root = Path(os.environ["ROOT"])
tokens_path = root / "shared/theme/tokens.json"
data = json.loads(tokens_path.read_text())

version = data.get("version", "")
required = ["typography", "colors", "spacing", "radius", "shadow", "animation", "layout"]
missing = [k for k in required if k not in data]
if missing:
    print(f"ERROR: missing top-level keys: {missing}", file=sys.stderr)
    sys.exit(1)

if data["typography"]["fontFamily"] != "Outfit":
    print("ERROR: fontFamily must be Outfit", file=sys.stderr)
    sys.exit(1)

spacing = set(data["spacing"].values())
allowed = {4, 8, 12, 16, 20, 24, 32, 40, 48}
bad = spacing - allowed
if bad:
    print(f"WARN: non-grid spacing values: {bad}")

print(f"OK  tokens.json v{version}")
print(f"    colors: {len(data['colors']['light'])} light / {len(data['colors']['dark'])} dark")
print(f"    spacing: {len(data['spacing'])} steps")
print(f"    radius.card = {data['radius']['card']}px")
print(f"    animations: {len(data['animation']['duration'])} durations")
PY

echo ""
echo "Platform files:"
export ROOT
python3 <<'PY'
import json, os
from pathlib import Path

root = Path(os.environ["ROOT"])
platforms = json.loads((root / "shared/theme/platforms.json").read_text())
for name, cfg in platforms["platforms"].items():
    tok = cfg.get("tokens", "")
    exists = (root / tok).exists() if tok else False
    status = "OK" if exists else "MISSING"
    print(f"  [{status}] {name}: {tok}")
PY

echo ""
echo "Done. Update platform implementations if tokens changed."
