# Local Send Protocol

Peer-to-peer LAN file transfer. **No cloud, no VPS, no database.**

## Discovery

- **Service type:** `_syncbridge-localsend._tcp`
- **TXT records:** `id` (device UUID), `name` (friendly name), `platform` (`android` | `macos` | `ios` | `windows` | `web`)
- Continuous mDNS browse; peers appear/disappear automatically.

## Transport

- Direct TCP from sender to receiver (host + port from mDNS SRV).
- Control: newline-delimited JSON (`\n`).
- Data: binary chunk frames after `file_begin`.

## Chunk frame

| Field       | Size   | Description        |
|------------|--------|--------------------|
| magic      | 4      | `SBLS`             |
| fileIndex  | 2 BE   | file in batch      |
| offset     | 8 BE   | byte offset        |
| length     | 4 BE   | payload bytes      |
| payload    | length | raw file bytes     |

**Chunk size:** 4 MiB (4 194 304 bytes).

## Control messages

```json
{"op":"offer","id":"<uuid>","sender":"<friendly name>","files":[{"index":0,"name":"Vacation.mp4","relativePath":"Vacation.mp4","size":12345678}]}
{"op":"accept","id":"<uuid>"}
{"op":"reject","id":"<uuid>","reason":"..."}
{"op":"file_begin","id":"<uuid>","index":0,"offset":0}
{"op":"chunk_ack","id":"<uuid>","index":0,"offset":4194304}
{"op":"file_end","id":"<uuid>","index":0}
{"op":"complete","id":"<uuid>"}
{"op":"resume","id":"<uuid>","index":0,"offset":8388608}
```

## Flow

1. Sender connects → sends `offer`.
2. Receiver `accept` or `reject`.
3. Per file: `file_begin` → chunk frames → `file_end`.
4. Sender sends `complete`.

## Resume

On disconnect, receiver keeps last verified offset per file. On reconnect, sender sends `offer` with same `id`; receiver replies `resume` with offsets; transfer continues from last ack.

## Received files

- **macOS/iOS:** `~/Downloads/SyncBridge/`
- **Android:** `Downloads/SyncBridge/`
