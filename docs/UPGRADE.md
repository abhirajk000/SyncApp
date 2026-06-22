# SyncBridge — Upgrade Guide

## Upgrade Strategy

SyncBridge follows **zero-downtime rolling upgrades** via database migrations and
backward-compatible API changes.  A new version must support the previous version's
requests until all clients have been updated.

---

## 1. Pre-Upgrade Checklist

- [ ] Read the release notes for breaking changes
- [ ] Back up the PostgreSQL database (`pg_dump`)
- [ ] Back up `KEY_ENCRYPTION_KEY` and `JWT_SECRET`
- [ ] Verify `GET /ready` returns `{"status":"ready"}` before starting
- [ ] Test on a staging environment first

---

## 2. Standard Upgrade (Docker Compose)

```bash
# 1. Pull the new image or rebuild from source
git pull
docker compose pull   # if using a registry
# OR
docker compose build  # if building from Dockerfile

# 2. Apply migrations first (before replacing the container)
#    The API runs migrations on startup when RUN_MIGRATIONS=true.
#    For manual control:
docker compose run --rm api migrate up

# 3. Replace the container with zero-downtime restart
docker compose up -d --no-deps --build api

# 4. Verify the new version is running
curl http://localhost:8080/version
curl http://localhost:8080/ready

# 5. Check logs for errors
docker compose logs --tail=50 api
```

---

## 3. Migration-Only Upgrade

If only database changes are needed (no code change):

```bash
export DATABASE_URL="postgres://..."
make migrate-up
```

Or via the container:

```bash
docker compose run --rm api migrate up
```

---

## 4. Rollback Procedure

```bash
# 1. Roll back one migration
docker compose run --rm api migrate down 1

# 2. Restore the previous container image
docker compose pull api:previous-tag
docker compose up -d --no-deps api

# 3. Verify
curl http://localhost:8080/health
```

For full rollback from a backup:

```bash
# See docs/BACKUP.md → "Restore from PostgreSQL Backup"
```

---

## 5. Migration Version History

| Migration | Phase | Description |
|---|---|---|
| 000001–000005 | Phase 2 | Initial schema: users, sessions, devices, audit logs |
| 000006 | Phase 5 | Clipboard entries |
| 000007 | Phase 5 | User keys (DEK storage) |
| 000008 | Phase 6 | mDNS local peers |
| 000009 | Phase 6 | WebRTC sessions |
| 000010 | Phase 7 | Files + file chunks |
| 000011 | Phase 7 | File transfer extensions |
| 000012 | Phase 7 | File metadata (thumbnails, compression) |
| 000013 | Phase 7 | File transfer mode |
| **000014** | **Phase 8** | **Retention: `pinned_at`, `user_settings`, 2-hour defaults** |

---

## 6. Key Rotation

### JWT Secret Rotation

All active sessions are invalidated when `JWT_SECRET` changes.  Users will need to log in again.

```bash
# 1. Generate new secret
NEW_SECRET=$(openssl rand -hex 32)

# 2. Update secret in your secrets manager
aws secretsmanager update-secret \
    --secret-id syncbridge/production/jwt-secret \
    --secret-string "$NEW_SECRET"

# 3. Restart API with new secret
JWT_SECRET="$NEW_SECRET" docker compose up -d --no-deps api
```

### KEK Rotation (advanced)

Rotating the `KEY_ENCRYPTION_KEY` requires re-wrapping every user's DEK.
**Do not rotate the KEK without running a migration first.**

> **Phase 9 upgrade step**: A DEK re-wrap migration will be added in a future release.
> Until then: keep the KEK stable and back it up securely.

---

## 7. Client Compatibility

| Server version | Minimum client version |
|---|---|
| 1.x.x (Phase 1–9) | macOS 1.0, Android 1.0, iOS 1.0, Web 1.0 |

Clients older than the minimum version will receive `400 Bad Request` or
`426 Upgrade Required` on deprecated endpoints.

---

## 8. Environment Variable Changes (Phase 8)

Phase 8 added:

| New variable | Default | Replaces |
|---|---|---|
| `DEFAULT_RETENTION_MINUTES` | `120` | `HISTORY_RETENTION_DAYS` (deprecated) |

The old `HISTORY_RETENTION_DAYS` and `FILE_RETENTION_DAYS` are still parsed but
ignored; remove them from your `.env` to avoid confusion.
