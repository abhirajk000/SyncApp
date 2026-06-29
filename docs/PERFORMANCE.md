# SyncBridge — Performance & Resource Usage

SyncBridge must feel **instant** while staying lightweight on RAM, CPU, and battery.

## Principles

1. **Event-driven over polling** — WebSocket push for clipboard; OS clipboard listeners (not periodic full sync).
2. **Foreground-first work** — Expensive UI, network refresh, and LAN discovery run when the user is active.
3. **Thumbnails in lists** — Never hold full-resolution images in list/history RAM; lazy-load thumbnails on demand.
4. **Stream large files** — Chunked upload/download; never load multi-MB buffers entirely into memory.
5. **Minimum background footprint** — Keep only clipboard sync + WS alive on mobile; pause everything else.

## Background

| Platform | Keep alive | Pause / stop |
|----------|------------|--------------|
| **Android** | `SyncClipboardService` (clip listener + WS) | LAN refresh, Local Send, UI bitmaps |
| **iOS** | WS briefly (~28s) after background | Clipboard monitor, Local Send, WS after grace |
| **macOS** | Clipboard monitor + WS (menu bar app) | Local Send + LAN refresh when app inactive |
| **Web** | Nothing when tab hidden | WS, LAN polling, network refresh |

## Foreground resume

On resume / tab visible:

1. Reconnect WebSocket immediately.
2. Catch up clipboard (`GET /clipboard/current` + history refresh).
3. Refresh UI from server (no full-page blocking spinners when possible).

## Memory

- Clipboard history API returns **metadata + thumbnails** for images (`has_thumbnail`), not full base64.
- Image thumbs: decode with **downsampling** (max ~512px edge).
- Bounded thumbnail caches (web: LRU ~48 entries with `URL.revokeObjectURL`).
- Compose `LazyColumn` / `LazyVerticalGrid` with stable keys for recycling.
- Clear decoded bitmaps when composables leave composition.

## Animations

- Target 60 FPS; prefer `transform` / `opacity` (GPU-friendly).
- Respect `prefers-reduced-motion` (disable stagger, parallax, press scale).
- Respect `prefers-reduced-data` (disable backdrop blur on glass surfaces).

## Network

- No continuous REST polling for clipboard — WS `clipboard.new` only.
- LAN peer refresh: **15s** foreground, **paused/slow** when UI/tab inactive (web/Android/macOS).
- Cloud file upload (Android): files **>4 MB** spooled to disk and uploaded in chunks (no full-RAM buffer).
- WS heartbeat: platform defaults (OkHttp 30s ping / app-level ping).

## Targets (aligns with global rules)

| Metric | Target |
|--------|--------|
| Backend idle RAM | <100 MB |
| Clipboard (Wi‑Fi) | <500 ms |
| Clipboard (cloud) | <2 s |
| Background battery | Minimal — essential sync only |
