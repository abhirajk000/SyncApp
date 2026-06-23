#!/usr/bin/env bash
# Test macOS clipboard image upload + copy round-trip.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/clients/macos/build/DerivedData/Build/Products/Release/SyncBridge.app"
TEST_IMG="$ROOT/clients/web/public/icon-512.png"
API="https://sync.abhiraj.xyz"

if [[ ! -d "$APP" ]]; then
  echo "Build the app first: scripts/build-macos-dmg.sh Release" >&2
  exit 1
fi

read_token() {
  python3 - <<'PY'
import plistlib, pathlib
paths = [
    pathlib.Path.home() / "Library/Preferences/com.syncbridge.mac.credentials.plist",
]
for p in paths:
    if p.exists():
        data = plistlib.loads(p.read_bytes())
        tok = data.get("credential.com.syncbridge.accessToken")
        dev = data.get("credential.com.syncbridge.deviceId")
        if tok:
            print(tok)
            print(dev or "")
            raise SystemExit(0)
raise SystemExit(1)
PY
}

echo "==> Restart SyncBridge (new build)"
pkill -x SyncBridge 2>/dev/null || true
sleep 1
open "$APP"
sleep 4

if ! CREDS=$(read_token); then
  echo "ERROR: SyncBridge not logged in — unlock with PIN in the menu bar app first." >&2
  exit 1
fi
TOKEN=$(echo "$CREDS" | sed -n '1p')
MAC_DEVICE=$(echo "$CREDS" | sed -n '2p')
echo "Using mac device_id=${MAC_DEVICE:0:8}..."

echo "==> Put test image on macOS clipboard"
osascript -e "set the clipboard to (read (POSIX file \"$TEST_IMG\") as «class PNGf»)"
echo "pasteboard types: $(osascript -e 'clipboard info' | head -3)"

echo "==> Wait for clipboard monitor upload"
sleep 3

echo "==> Check latest clipboard on server"
CURRENT_JSON=$(curl -sS -H "Authorization: Bearer $TOKEN" "$API/api/v1/clipboard/current")
echo "$CURRENT_JSON" | python3 -c "
import sys, json
entry = json.load(sys.stdin)
ct = entry.get('content_type', '')
clen = len(entry.get('content', ''))
print('current:', entry.get('id'), ct, 'content_len', clen, 'device', entry.get('source_device_id','')[:8])
if not ct.startswith('image/'):
    raise SystemExit('FAIL: latest entry is not an image')
if clen < 100:
    raise SystemExit('FAIL: image content too small')
print('UPLOAD OK')
"

echo "==> Copy latest image entry back to pasteboard (app logic)"
ENTRY_ID=$(echo "$CURRENT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

ENTRY_JSON=$(curl -sS -H "Authorization: Bearer $TOKEN" "$API/api/v1/clipboard/$ENTRY_ID")
echo "$ENTRY_JSON" | python3 -c "
import sys, json, base64, subprocess, tempfile, os
entry = json.load(sys.stdin)
raw = entry['content'].strip()
data = base64.b64decode(raw)
with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as f:
    f.write(data)
    tmp = f.name
subprocess.run([
    'osascript', '-e',
    f'set the clipboard to (read (POSIX file \"{tmp}\") as JPEG picture)'
], check=True)
os.unlink(tmp)
info = subprocess.check_output(['osascript', '-e', 'clipboard info'], text=True)
print('pasteboard types after copy:', info.strip().split(chr(10))[0])
if 'picture' not in info.lower() and 'jpeg' not in info.lower() and 'png' not in info.lower():
    raise SystemExit('FAIL: pasteboard has no image type')
print('COPY OK')
"

echo ""
echo "All macOS clipboard image tests passed."
