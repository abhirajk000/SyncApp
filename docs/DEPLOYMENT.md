# SyncBridge — Deployment Guide

## Prerequisites

| Requirement | Version |
|---|---|
| Docker | 24+ |
| Docker Compose | V2 (built-in `docker compose`) |
| PostgreSQL | 16 (managed by Compose) |
| MinIO / S3 | any (managed by Compose for self-host) |

---

## 1. Quick Start (Self-Hosted, one command)

```bash
# 1. Clone the repository
git clone https://github.com/your-org/syncbridge
cd syncbridge

# 2. Generate secrets
JWT_SECRET=$(openssl rand -hex 32)
KEK=$(openssl rand -hex 32)

# 3. Set secrets in environment (or a .env file — never commit secrets)
export JWT_SECRET="$JWT_SECRET"
export KEY_ENCRYPTION_KEY="$KEK"

# 4. Start everything
docker compose up -d

# 5. Verify
curl http://localhost:8080/health        # → {"status":"ok"}
curl http://localhost:8080/ready         # → {"status":"ready",...}
```

The stack starts:
- **API** on `http://localhost:8080`
- **PostgreSQL 16** on `localhost:5432`
- **MinIO** on `localhost:9000` (console: `localhost:9001`)

---

## 2. Environment Variables (Production)

Set these as real environment variables (not a `.env` file) in production.

### Required

| Variable | Example | Description |
|---|---|---|
| `DATABASE_URL` | `postgres://sb:pass@db:5432/sb?sslmode=require` | PostgreSQL DSN |
| `JWT_SECRET` | `$(openssl rand -hex 32)` | HMAC-SHA256 signing key (≥32 chars) |
| `KEY_ENCRYPTION_KEY` | `$(openssl rand -hex 32)` | 32-byte hex KEK for clipboard encryption |

### Storage

| Variable | Default | Description |
|---|---|---|
| `OBJECT_STORAGE_TYPE` | `local` | `local` \| `s3` \| `minio` |
| `S3_BUCKET` | — | S3 bucket name |
| `S3_REGION` | `us-east-1` | AWS region |
| `S3_ENDPOINT` | — | MinIO endpoint URL (omit for AWS) |
| `S3_ACCESS_KEY` | — | Access key ID |
| `S3_SECRET_KEY` | — | Secret access key |

### Retention

| Variable | Default | Description |
|---|---|---|
| `DEFAULT_RETENTION_MINUTES` | `120` | Server default (2 h). Users may override. |

### WebRTC (optional)

| Variable | Example | Description |
|---|---|---|
| `STUN_URLS` | `stun:stun.l.google.com:19302` | Comma-separated STUN URIs |
| `TURN_URLS` | `turn:turn.example.com:3478` | Comma-separated TURN URIs |
| `TURN_SECRET` | `$(openssl rand -hex 32)` | coturn HMAC secret |

---

## 3. Production Docker Compose Override

Create `docker-compose.prod.yml`:

```yaml
version: "3.9"
services:
  api:
    restart: always
    environment:
      ENVIRONMENT:     production
      LOG_FORMAT:      json
      TLS_MODE:        off         # let Caddy handle TLS
      MDNS_ENABLED:    "false"     # disable in cloud
      CORS_ORIGINS:    "https://app.yourdomain.com"
      DATABASE_URL:    "${DATABASE_URL}"
      JWT_SECRET:      "${JWT_SECRET}"
      KEY_ENCRYPTION_KEY: "${KEY_ENCRYPTION_KEY}"
      OBJECT_STORAGE_TYPE: s3
      S3_BUCKET:       "${S3_BUCKET}"
      S3_REGION:       "${S3_REGION}"
      S3_ACCESS_KEY:   "${S3_ACCESS_KEY}"
      S3_SECRET_KEY:   "${S3_SECRET_KEY}"
    labels:
      caddy: "api.yourdomain.com"
      caddy.reverse_proxy: "{{upstreams 8080}}"
```

Start with:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## 4. Reverse Proxy (Caddy)

```caddyfile
api.yourdomain.com {
    reverse_proxy localhost:8080
    encode gzip
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Frame-Options DENY
        X-Content-Type-Options nosniff
    }
}
```

---

## 5. TLS Certificate (Let's Encrypt via Caddy)

Caddy handles TLS automatically when `api.yourdomain.com` resolves to the server's public IP.  No additional configuration is required.

---

## 6. Database: Managed PostgreSQL

For production, use a managed PostgreSQL service (AWS RDS, Supabase, Neon):

1. Create a database: `syncbridge`
2. Create a user with `CREATE TABLE`, `CREATE INDEX`, `INSERT`, `UPDATE`, `DELETE`, `SELECT` privileges.
3. Set `DATABASE_URL` to the DSN.
4. Set `RUN_MIGRATIONS=true` (runs once on startup).

---

## 7. Healthchecks

| Endpoint | Auth | Purpose |
|---|---|---|
| `GET /health` | None | Liveness: returns `200` if process is up |
| `GET /ready` | None | Readiness: returns `200` only after DB + migrations are done |
| `GET /version` | None | Build metadata |
| `GET /api/v1/diagnostics` | Bearer JWT | Per-user connection diagnostics |

Use `/ready` as the load-balancer health check target.

---

## 8. First-Run Checklist

- [ ] `DATABASE_URL` points to PostgreSQL 16
- [ ] `JWT_SECRET` is ≥ 32 bytes, random, unique per environment
- [ ] `KEY_ENCRYPTION_KEY` is exactly 64 hex chars, **backed up securely**
- [ ] `CORS_ORIGINS` includes only your app's origin
- [ ] Object storage bucket exists and credentials have write permissions
- [ ] TURN server is configured (optional, but required for cross-NAT file transfer)
- [ ] `GET /ready` returns `{"status":"ready"}` after startup

---

## 9. VPS Production (sync.abhiraj.xyz — alongside K12Hunar)

**Do not touch:** K12Hunar PostgreSQL, nginx sites, ports `3000` / `8080` / `5432`.

### Layout

```
/root
├── k12hunar
└── syncapp

/opt
├── k12hunar -> /root/k12hunar
└── syncapp  -> /root/syncapp
```

### Ports (localhost only)

| Service | Bind | Public domain |
|---------|------|---------------|
| Web dashboard | `127.0.0.1:2000` | `sync.abhiraj.xyz` |
| API + WebSocket | `127.0.0.1:2001` | `api.sync.abhiraj.xyz` |

### Database

Uses **host PostgreSQL** (no Postgres container):

```sql
CREATE ROLE syncbridge_user LOGIN PASSWORD '...';
CREATE DATABASE syncbridge OWNER syncbridge_user;
```

`pg_hba.conf` — Docker bridge only:

```
host  syncbridge  syncbridge_user  172.16.0.0/12  scram-sha-256
```

### Deploy

```bash
cd /root/syncapp
bash scripts/deploy-vps.sh
# or: deploy-sync
```

Uses `docker-compose.vps.yml` (API + web nginx, no Postgres).

### SSL

After DNS A records point to the VPS (`87.232.72.185` or grey-cloud in Cloudflare):

```bash
certbot certonly --webroot -w /var/www/certbot \
  -d sync.abhiraj.xyz -d api.sync.abhiraj.xyz
cp deploy/nginx-syncbridge.conf /etc/nginx/sites-available/syncbridge
nginx -t && systemctl reload nginx
```

Certificate path: `/etc/letsencrypt/live/sync.abhiraj.xyz/`

### Client URLs

| Client | Server URL | PIN |
|--------|------------|-----|
| Mac / Web / iOS / Android | `https://api.sync.abhiraj.xyz` | `070901` |
| Web dashboard | `https://sync.abhiraj.xyz` | `070901` |

WebSocket: `wss://api.sync.abhiraj.xyz/ws` (derived from API URL in clients).

### Migrating from abhiraj.xyz → sync.abhiraj.xyz

1. **DNS** — Add A records (or CNAME) for `sync.abhiraj.xyz` and `api.sync.abhiraj.xyz` → VPS IP. Wait for propagation.
2. **Pull** — `cd /root/syncapp && git pull`
3. **CORS** — In `/root/syncapp/.env` set:
   ```
   CORS_ORIGINS=https://sync.abhiraj.xyz,https://api.sync.abhiraj.xyz
   ```
4. **SSL** — Issue cert (see above). Old `abhiraj.xyz` cert is not reused.
5. **Deploy** — `deploy-sync` (rebuilds web with `VITE_API_URL=https://api.sync.abhiraj.xyz`).
6. **Verify** — `health-sync` or:
   ```bash
   curl -sI https://sync.abhiraj.xyz | head -1
   curl -s https://api.sync.abhiraj.xyz/ready
   ```
7. **Clients** — Update server URL on paired devices to `https://api.sync.abhiraj.xyz`.
8. **Optional** — Remove old SyncBridge `server_name` blocks from nginx if `abhiraj.xyz` / `api.abhiraj.xyz` were only used for SyncBridge (do not touch K12Hunar vhosts).
