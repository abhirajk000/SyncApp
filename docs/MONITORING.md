# SyncBridge — Monitoring Guide

## 1. Key Metrics to Watch

### API Health

| Metric | Target | Alert threshold |
|---|---|---|
| `GET /health` response time | < 50 ms | > 500 ms |
| `GET /ready` status code | 200 | non-200 |
| HTTP 5xx error rate | < 0.1 % | > 1 % |
| HTTP 4xx error rate | < 5 % | > 20 % |

### Database

| Metric | Target | Alert threshold |
|---|---|---|
| Idle connections | 2–5 | > `DB_MAX_CONNS` × 0.9 |
| Query latency (p99) | < 50 ms | > 500 ms |
| Replication lag | N/A | > 30 s (if using replicas) |
| Disk usage | < 70 % | > 85 % |

### Backend Memory

| Component | Target idle | Alert threshold |
|---|---|---|
| API process RSS | < 50 MB | > 200 MB |
| PostgreSQL | < 256 MB | > 1 GB |

### WebSocket

| Metric | Target | Alert threshold |
|---|---|---|
| Active WS connections | baseline | drop to 0 unexpectedly |
| Broadcast latency (p99) | < 5 ms | > 100 ms |
| Disconnected client count | 0 | > 10 % of active |

---

## 2. Docker Stats (quick check)

```bash
# Live resource usage for all containers
docker stats

# API process memory
docker exec syncbridge-api cat /proc/$(pgrep api)/status | grep VmRSS
```

---

## 3. Structured Log Monitoring

SyncBridge emits JSON logs (`LOG_FORMAT=json` in production).  Key log fields:

```json
{
  "level":       "info",
  "service":     "syncbridge-api",
  "version":     "1.2.0",
  "request_id":  "uuid",
  "method":      "POST",
  "path":        "/api/v1/clipboard",
  "status":      201,
  "latency_ms":  12,
  "user_id":     "uuid",
  "device_id":   "uuid"
}
```

### Log levels

| Level | Meaning |
|---|---|
| `debug` | Verbose internal state (development only) |
| `info`  | Normal request lifecycle, startup events |
| `warn`  | Non-fatal issues (mDNS failure, slow query) |
| `error` | Failures requiring attention |

### Useful log queries (grep / jq)

```bash
# All 5xx errors in the last hour
docker compose logs api --since 1h | jq 'select(.status >= 500)'

# Slow requests (> 200 ms)
docker compose logs api | jq 'select(.latency_ms > 200)'

# Cleanup job activity
docker compose logs api | jq 'select(.service == "cleanup")'

# Rate limit events
docker compose logs api | grep "rate limit"
```

---

## 4. Uptime Monitoring

Add these endpoints to an external monitor (BetterUptime, UptimeRobot, etc.):

| URL | Expected | Check interval |
|---|---|---|
| `https://api.yourdomain.com/health` | `200` | 60 s |
| `https://api.yourdomain.com/ready`  | `200` | 60 s |

---

## 5. PostgreSQL Monitoring Queries

```sql
-- Active connections
SELECT count(*), state FROM pg_stat_activity GROUP BY state;

-- Longest running query
SELECT pid, now() - pg_stat_activity.query_start AS duration, query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC
LIMIT 5;

-- Table sizes
SELECT relname AS table, pg_size_pretty(pg_total_relation_size(relid)) AS size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;

-- Expired items still in tables (should be 0 after cleanup job runs)
SELECT 'clipboard' AS tbl, count(*) FROM clipboard_entries
WHERE pinned = false AND expires_at < now()
UNION ALL
SELECT 'files', count(*) FROM files
WHERE is_pinned = false AND expires_at < now();
```

---

## 6. Memory Profiling (Go pprof)

Add to server startup for production profiling access (behind auth!):

```bash
# One-shot heap profile
curl http://localhost:8080/debug/pprof/heap > heap.prof
go tool pprof -http=:8081 heap.prof

# 30-second CPU profile
curl "http://localhost:8080/debug/pprof/profile?seconds=30" > cpu.prof
go tool pprof -http=:8081 cpu.prof
```

Enable pprof in the server by adding `_ "net/http/pprof"` and an HTTP mux on a separate port.

---

## 7. Alert Rules (Prometheus / Alertmanager example)

```yaml
groups:
  - name: syncbridge
    rules:
      - alert: APIDown
        expr: probe_success{job="syncbridge"} == 0
        for: 1m
        labels:
          severity: critical

      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.01
        for: 5m
        labels:
          severity: warning

      - alert: DatabaseConnectionExhausted
        expr: pg_stat_activity_count > 20
        for: 2m
        labels:
          severity: warning
```

---

## 8. macOS Client Memory Target

The macOS menu bar app targets **< 30 MB** idle RSS.  Verify:

```bash
# Find the process
pgrep -x SyncBridgeMac

# Check RSS (in KB)
ps -o rss= -p $(pgrep -x SyncBridgeMac)

# Detailed memory with Activity Monitor
# Applications → Utilities → Activity Monitor → Search "SyncBridgeMac" → Memory column
```
