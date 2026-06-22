# SyncBridge — Manual Test Checklist

Use this checklist for end-to-end validation before every release.  
Mark each item ✅ when it passes, ❌ when it fails (with a note).

---

## 0. Environment Setup

```bash
# Start the complete backend
docker compose up -d

# Wait for all services to be healthy
docker compose ps          # all should show "healthy"
curl http://localhost:8080/ready  # → {"status":"ready"}
curl http://localhost:8080/version
```

---

## 1. Authentication (PIN unlock)

Default master PIN: **`070901`** (seeded in DB via migration `000015`).

```bash
# Unlock a device (creates device if new UUID)
curl -s -X POST http://localhost:8080/api/v1/auth/unlock \
  -H 'Content-Type: application/json' \
  -d '{"pin":"070901","device_id":"00000000-0000-4000-8000-000000000101","device_name":"Test Mac","platform":"macos"}'
```

| # | Test | Expected | Result |
|---|---|---|---|
| 1.1 | Unlock with correct PIN (`POST /auth/unlock`) | `200` with 7-day access + refresh tokens, `trusted_until` | |
| 1.2 | Unlock with wrong PIN | `401 invalid pin` | |
| 1.3 | Unlock 6th distinct device (max 5) | `409 maximum number of devices reached` | |
| 1.4 | Access protected endpoint without token | `401 Unauthorized` | |
| 1.5 | Access protected endpoint with expired token | `401 token expired` | |
| 1.6 | Status while trusted (`GET /auth/status`) | `200`, `needs_pin: false` | |
| 1.7 | Status after `trusted_until` passes | `200`, `needs_pin: true` | |
| 1.8 | Re-unlock same device with PIN | `200`, trust window extended 7 days | |
| 1.9 | Logout (`POST /auth/logout`) | `200`, session revoked | |
| 1.10 | API call after logout | `401` | |
| 1.11 | Rate limit: > 10 unlock attempts in 60 s | `429 Too Many Requests` | |

---

## 2. Device Pairing

| # | Test | Expected | Result |
|---|---|---|---|
| 2.1 | Unlock macOS device via PIN | `200`, device ID in response | |
| 2.2 | Initiate QR pairing on Mac | `200`, pairing code returned | |
| 2.3 | Confirm pairing on Android (scan QR) | `200`, both devices trusted | |
| 2.4 | Initiate pairing on iPhone (scan QR from Mac) | `200`, three devices trusted | |
| 2.5 | Open web dashboard → device shows as trusted | Device listed in `GET /devices` | |
| 2.6 | List devices (`GET /devices`) | All 4 devices appear | |
| 2.7 | Revoke Android device | `204`, Android device inactive | |
| 2.8 | Attempt clipboard sync from revoked device | `401` | |

---

## 3. Clipboard Sync

### 3a. Text

| # | Test | Expected | Result |
|---|---|---|---|
| 3.1 | Copy "Hello World" on Mac | Appears on Android within 500 ms (Wi-Fi) | |
| 3.2 | Copy URL on Mac | Appears on iPhone with correct content-type `text/uri-list` | |
| 3.3 | Copy 5000-char text on Android | Syncs to Mac within 500 ms | |
| 3.4 | Copy same text twice | Second sync returns `deduplicated: true` | |
| 3.5 | Copy on iPhone → Mac, then Mac → Android | Propagates in correct order | |
| 3.6 | Copy text > 10 MB | `413 Request Entity Too Large` | |

### 3b. History & Retention

| # | Test | Expected | Result |
|---|---|---|---|
| 3.7 | `GET /clipboard` — history appears | Last 50 items returned, newest first | |
| 3.8 | Wait 2 hours + cleanup job | Unpinned items removed automatically | |
| 3.9 | Pin item before 2 hours | Item persists after 2 hours | |
| 3.10 | Unpin previously pinned item | Re-arms 2-hour expiry timer | |
| 3.11 | All devices see pin state change | `clipboard.pin` WS event delivered | |
| 3.12 | Change retention to 30 min | New items expire after 30 min | |

---

## 4. Images & Screenshots

| # | Test | Expected | Result |
|---|---|---|---|
| 4.1 | Capture screenshot on Mac → sync | JPEG thumbnail generated, appears on Android | |
| 4.2 | Capture screenshot on Android → Mac | Image transferred, thumbnail visible | |
| 4.3 | `GET /files/:id/thumbnail` | Returns 256×256 JPEG | |
| 4.4 | Download full screenshot | SHA-256 matches original | |

---

## 5. File Transfer

| # | Test | Expected | Result |
|---|---|---|---|
| 5.1 | Transfer 1 MB PDF Mac → Android | Completes, checksum matches | |
| 5.2 | Transfer 10 MB ZIP Mac → iPhone | Completes within 30 s on Wi-Fi | |
| 5.3 | Transfer 100 MB video | Chunked upload, progress events received | |
| 5.4 | Interrupt transfer at 50% and resume | `GET /files/:id/status` shows missing chunks; resume completes | |
| 5.5 | Transfer with wrong chunk hash | `422 Unprocessable Entity` | |
| 5.6 | Transfer with wrong file hash on complete | `422 Unprocessable Entity` | |
| 5.7 | Pin a transferred file | File persists beyond 2-hour default | |
| 5.8 | Attempt to delete a pinned file | `404 Not Found` (soft-delete blocked) | |

---

## 6. Same Wi-Fi (Local Network)

Both devices must be connected to the same router.

| # | Test | Expected | Result |
|---|---|---|---|
| 6.1 | Check diagnostics page on Mac | `local_peers ≥ 1` when Android on same network | |
| 6.2 | mDNS discovery | `mdns_enabled: true` in diagnostics | |
| 6.3 | File transfer (Wi-Fi): 10 MB | Completes in < 5 s (direct WebRTC) | |
| 6.4 | Verify cloud relay not used | Check server access logs — no `/api/v1/files/:id/chunks` traffic during WebRTC transfer | |
| 6.5 | Measure clipboard sync latency | < 500 ms end-to-end | |

### Diagnostics Page Verification

```bash
# Get a JWT by logging in, then:
curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8080/api/v1/diagnostics | jq
```

Expected response:
```json
{
  "server_version": "...",
  "client_ip": "192.168.x.x",
  "local_peers": 2,
  "mdns_enabled": true,
  "stun_urls": ["stun:stun.l.google.com:19302"],
  "turn_enabled": false,
  "storage_backend": "minio",
  "default_retention_minutes": 120,
  "retention_minutes": 120
}
```

---

## 7. Different Networks (Cloud Relay)

Mac on Wi-Fi, Android on cellular data (or use VPN to simulate).

| # | Test | Expected | Result |
|---|---|---|---|
| 7.1 | Clipboard sync | Syncs within 2 s | |
| 7.2 | Image sync | Transfers via cloud relay | |
| 7.3 | 1 MB file transfer | Completes via relay | |
| 7.4 | Diagnostics: `local_peers` | `0` (no same-LAN peer) | |

---

## 8. Performance Benchmarks

Run the Go benchmarks:

```bash
make bench
```

Expected results (indicative):

| Benchmark | Target | Actual |
|---|---|---|
| `BenchmarkSync_Short` | < 500 µs/op | |
| `BenchmarkSync_1KB` | < 1 ms/op | |
| `BenchmarkSync_10KB` | < 5 ms/op | |
| `BenchmarkSync_Dedup` | < 100 µs/op | |
| `BenchmarkBroadcast_5Devices` | < 10 µs/op | |

---

## 9. Security Tests

| # | Test | Expected | Result |
|---|---|---|---|
| 9.1 | Send request with tampered JWT signature | `401 invalid token` | |
| 9.2 | Send request with JWT from a different user | Resources of other user not accessible | |
| 9.3 | Brute-force PIN unlock (> 10 attempts / 60 s) | `429 Too Many Requests` | |
| 9.4 | Access another user's clipboard entry by ID | `404 Not Found` | |
| 9.5 | Access another user's file by ID | `404 Not Found` | |
| 9.6 | Access WS hub without auth | Upgrade rejected (`401`) | |
| 9.7 | Upload file with unsupported MIME type | `400 unsupported MIME type` | |
| 9.8 | Clipboard sync with unsupported content-type | `400 unsupported content type` | |
| 9.9 | CORS: request from unlisted origin | CORS headers absent / blocked | |
| 9.10 | Re-use revoked device token | `401` | |

---

## 10. Failure & Recovery Tests

| # | Test | Expected | Result |
|---|---|---|---|
| 10.1 | Restart API container | Clients reconnect within 5 s (exponential backoff) | |
| 10.2 | Restart PostgreSQL | API logs DB reconnect; `GET /ready` returns `200` again | |
| 10.3 | Kill network on Mac mid-sync | Mac retries, sync completes after reconnect | |
| 10.4 | Kill network on Android mid-upload | Resume upload from last chunk | |
| 10.5 | Full server restart (all containers) | `docker compose restart` → all services healthy in < 30 s | |
| 10.6 | Database OOM kill | pgxpool reconnects automatically | |

---

## 11. Memory Validation

```bash
# Backend idle memory
docker stats syncbridge-api --no-stream --format "table {{.MemUsage}}"
# Target: < 50 MB

# macOS client idle
ps -o rss= -p $(pgrep -x SyncBridgeMac)
# Target: < 30,000 KB (30 MB)
```

---

## 12. Release Gate

All items below must be ✅ before tagging a release:

- [ ] Sections 1–5 fully green
- [ ] Security section (9) fully green
- [ ] `make test-cover` reports ≥ 80% total coverage
- [ ] `make bench` shows no regressions vs. previous release
- [ ] `docker compose up -d` starts all services in < 60 s
- [ ] `GET /ready` returns `200` after startup
- [ ] Backup/restore procedure tested on staging
- [ ] `KEY_ENCRYPTION_KEY` and `JWT_SECRET` backed up securely
- [ ] Release notes written
