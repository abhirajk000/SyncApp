#!/usr/bin/env bash
# Smoke-test iOS clipboard image API paths (no device UI required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="https://sync.abhiraj.xyz"
TOKEN=$(python3 - <<'PY'
import plistlib, pathlib
p = pathlib.Path.home() / "Library/Preferences/com.syncbridge.mac.credentials.plist"
if p.exists():
    d = plistlib.loads(p.read_bytes())
    print(d.get("credential.com.syncbridge.accessToken", ""))
PY
)

if [[ -z "$TOKEN" ]]; then
  echo "Need a logged-in SyncBridge token (macOS app credentials)." >&2
  exit 1
fi

auth=(-H "Authorization: Bearer $TOKEN")

echo "==> GET /api/v1/clipboard?limit=5 (iOS fixed endpoint)"
code=$(curl -sS -o /tmp/ios_hist.json -w "%{http_code}" "${auth[@]}" "$API/api/v1/clipboard?limit=5")
echo "HTTP $code"
python3 -c "import json; d=json.load(open('/tmp/ios_hist.json')); print('entries', len(d.get('entries',[])))"

echo "==> POST image/jpeg upload (simulates iOS compression)"
B64=$(python3 -c "import base64; print(base64.b64encode(open('$ROOT/clients/web/public/icon-192.png','rb').read()).decode())")
curl -sS "${auth[@]}" -H 'Content-Type: application/json' \
  -d "{\"content_type\":\"image/jpeg\",\"content\":\"$B64\"}" \
  "$API/api/v1/clipboard" | python3 -c "import sys,json; d=json.load(sys.stdin); print('uploaded', d.get('id'), d.get('content_type'))"

ENTRY_ID=$(curl -sS "${auth[@]}" "$API/api/v1/clipboard/current" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
echo "==> GET /api/v1/clipboard/$ENTRY_ID (iOS copy fetch)"
curl -sS "${auth[@]}" "$API/api/v1/clipboard/$ENTRY_ID" | python3 -c "import sys,json; d=json.load(sys.stdin); print('fetch len', len(d.get('content','')), 'thumb', d.get('has_thumbnail'))"

echo "==> GET thumbnail"
curl -sS -o /dev/null -w "HTTP %{http_code}, %{size_download} bytes\n" "${auth[@]}" "$API/api/v1/clipboard/$ENTRY_ID/thumbnail"

echo ""
echo "iOS API smoke tests passed."
