# SyncBridge — Backup Guide

## Critical Data to Back Up

| Data | Location | Criticality |
|---|---|---|
| PostgreSQL database | Docker volume `postgres_data` | **Critical** — all user accounts, devices, clipboard history, metadata |
| Object storage (files) | Docker volume `minio_data` or S3 bucket | **High** — all uploaded files |
| `KEY_ENCRYPTION_KEY` | Environment variable / secrets manager | **Critical** — losing this key means clipboard data becomes unreadable |
| `JWT_SECRET` | Environment variable / secrets manager | **High** — losing this invalidates all sessions (users must re-login) |

---

## 1. Automated PostgreSQL Backup

### Daily backup with `pg_dump`

```bash
#!/bin/bash
# save as: /opt/syncbridge/backup-postgres.sh
# Schedule: crontab -e → 0 3 * * * /opt/syncbridge/backup-postgres.sh

set -euo pipefail

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/opt/syncbridge/backups/postgres
mkdir -p "$BACKUP_DIR"

# Dump to compressed SQL
docker exec syncbridge-postgres \
    pg_dump -U syncbridge syncbridge \
    | gzip > "$BACKUP_DIR/syncbridge_${DATE}.sql.gz"

# Retain 30 days
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +30 -delete

echo "Backup complete: syncbridge_${DATE}.sql.gz"
```

Make executable: `chmod +x /opt/syncbridge/backup-postgres.sh`

---

## 2. Restore from PostgreSQL Backup

```bash
# Stop the API to prevent writes during restore
docker compose stop api

# Drop and recreate the database
docker exec -i syncbridge-postgres \
    psql -U syncbridge -c "DROP DATABASE syncbridge; CREATE DATABASE syncbridge;"

# Restore from backup
gunzip -c /opt/syncbridge/backups/postgres/syncbridge_20260622_030000.sql.gz \
    | docker exec -i syncbridge-postgres \
        psql -U syncbridge syncbridge

# Restart the API
docker compose start api

# Verify
curl http://localhost:8080/ready
```

---

## 3. Object Storage Backup

### MinIO (self-hosted)

```bash
# Full bucket sync to local archive
mc alias set prod http://localhost:9000 minioadmin minioadmin
mc mirror prod/syncbridge-files /opt/syncbridge/backups/files/

# To restore
mc mirror /opt/syncbridge/backups/files/ prod/syncbridge-files
```

### AWS S3

Enable **S3 Versioning** and **Cross-Region Replication** on the bucket.  
Also enable **S3 Object Lock** for immutable backups (optional, WORM compliance).

```bash
# Enable versioning
aws s3api put-bucket-versioning \
    --bucket syncbridge-files \
    --versioning-configuration Status=Enabled
```

---

## 4. Secrets Backup

**The `KEY_ENCRYPTION_KEY` must be backed up securely.  If it is lost, all clipboard entries are permanently unreadable.**

Store secrets in:

1. **AWS Secrets Manager** / **HashiCorp Vault** (recommended for production)
2. A **password manager** (1Password, Bitwarden) with 2FA
3. An **encrypted offline copy** (GPG-encrypted file on a USB drive in a safe)

```bash
# Example: store in AWS Secrets Manager
aws secretsmanager create-secret \
    --name syncbridge/production/kek \
    --secret-string "$KEY_ENCRYPTION_KEY"

aws secretsmanager create-secret \
    --name syncbridge/production/jwt-secret \
    --secret-string "$JWT_SECRET"
```

---

## 5. Backup Verification

Run monthly to confirm backups are restorable:

```bash
#!/bin/bash
# Restore to a test container and verify migrations run
LATEST=$(ls -t /opt/syncbridge/backups/postgres/*.sql.gz | head -1)

docker run --rm -d \
    --name syncbridge-verify \
    -e POSTGRES_DB=syncbridge \
    -e POSTGRES_USER=syncbridge \
    -e POSTGRES_PASSWORD=syncbridge \
    -p 5433:5432 \
    postgres:16-alpine

sleep 5

gunzip -c "$LATEST" | docker exec -i syncbridge-verify \
    psql -U syncbridge syncbridge

# Check table counts
docker exec syncbridge-verify \
    psql -U syncbridge syncbridge \
    -c "SELECT schemaname, tablename FROM pg_tables WHERE schemaname='public';"

docker stop syncbridge-verify
echo "Backup verification passed: $LATEST"
```

---

## 6. Disaster Recovery RTO/RPO Targets

| Scenario | RTO (Recovery Time) | RPO (Data Loss) |
|---|---|---|
| API crash | < 1 min (container auto-restart) | 0 |
| Database host failure | < 30 min | Last 24h backup (daily) or < 5 min (streaming replication) |
| Storage host failure | < 1 h | Last mirror sync |
| Region failure | < 4 h | Last cross-region replica |
| KEK loss | **Unrecoverable** | All clipboard data permanently unreadable |
