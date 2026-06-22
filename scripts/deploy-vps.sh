#!/usr/bin/env bash
# Deploy SyncBridge on VPS alongside K12Hunar (no port/DB conflicts).
# Run on VPS as root from /root/syncapp after git pull.
set -euo pipefail

ROOT=/root/syncapp
OPT_LINK=/opt/syncapp

cd "$ROOT"

if [ -f config/syncapp-vps.env ]; then
  set -a
  # shellcheck source=/dev/null
  source config/syncapp-vps.env
  set +a
fi

SYNC_WEB_DOMAIN="${SYNC_WEB_DOMAIN:-sync.abhiraj.xyz}"
SYNC_API_DOMAIN="${SYNC_API_DOMAIN:-api.sync.abhiraj.xyz}"
VITE_API_URL="${VITE_API_URL:-https://${SYNC_API_DOMAIN}}"

echo "==> Directory layout"
mkdir -p "$ROOT/data/storage" "$ROOT/deploy"
if [ -d "$OPT_LINK" ] && [ ! -L "$OPT_LINK" ]; then
  rm -rf "$OPT_LINK"
fi
ln -sfn "$ROOT" "$OPT_LINK"

echo "==> Stop legacy Docker Postgres (use host PostgreSQL)"
docker compose -p syncapp down 2>/dev/null || true
docker rm -f syncbridge-postgres 2>/dev/null || true

echo "==> Build web dashboard (API: ${VITE_API_URL})"
if [ -f clients/web/dist/index.html ]; then
  echo "Using existing clients/web/dist"
elif command -v npm >/dev/null 2>&1; then
  cd clients/web
  npm ci
  VITE_API_URL="${VITE_API_URL}" npm run build
  cd "$ROOT"
else
  echo "ERROR: no clients/web/dist and npm missing" >&2
  exit 1
fi

echo "==> Start SyncBridge stack (ports 2000 web, 2001 api)"
docker compose -f docker-compose.vps.yml -p syncbridge up -d --build

echo "==> Health check"
for i in $(seq 1 30); do
  if curl -sf http://127.0.0.1:2001/ready >/dev/null; then
    echo "API ready on :2001"
    break
  fi
  sleep 2
done
curl -sf http://127.0.0.1:2001/ready || { docker compose -f docker-compose.vps.yml -p syncbridge logs --tail=30 api; exit 1; }
curl -sf -o /dev/null -w "Web :2000 → %{http_code}\n" http://127.0.0.1:2000/

echo "==> Install nginx site (does not modify k12hunar)"
CERT_PATH="/etc/letsencrypt/live/${SYNC_WEB_DOMAIN}/fullchain.pem"
if [ -f "$CERT_PATH" ]; then
  cp deploy/nginx-syncbridge.conf /etc/nginx/sites-available/syncbridge
  ln -sf /etc/nginx/sites-available/syncbridge /etc/nginx/sites-enabled/syncbridge
  rm -f /etc/nginx/sites-enabled/syncapp 2>/dev/null || true
  nginx -t && systemctl reload nginx
  echo "nginx reloaded (SSL cert present)"
else
  cp deploy/nginx-syncbridge-http.conf /etc/nginx/sites-available/syncbridge
  ln -sf /etc/nginx/sites-available/syncbridge /etc/nginx/sites-enabled/syncbridge
  rm -f /etc/nginx/sites-enabled/syncapp 2>/dev/null || true
  nginx -t && systemctl reload nginx
  echo "nginx HTTP-only (cert missing). After DNS → VPS, run:"
  echo "  certbot certonly --webroot -w /var/www/certbot -d ${SYNC_WEB_DOMAIN} -d ${SYNC_API_DOMAIN}"
  echo "  cp $ROOT/deploy/nginx-syncbridge.conf /etc/nginx/sites-available/syncbridge && nginx -t && systemctl reload nginx"
fi

docker compose -f docker-compose.vps.yml -p syncbridge ps
echo "Done."
