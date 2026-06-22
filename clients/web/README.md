# SyncBridge — Web Client

Minimal Vite + React + TypeScript scaffold for Phase D+E.

## Requirements

| Tool   | Version |
|--------|---------|
| Node.js| 20+     |
| npm    | 10+     |

## Setup

```bash
cd clients/web
npm install
npm run dev
```

Open http://localhost:5173. API calls proxy to the backend via Vite (`/api` → `http://localhost:8080`).

For production builds, set the server URL in the unlock screen or ensure the API is served from the same origin.

## Configuration

| Setting     | Default                 | Storage        |
|-------------|-------------------------|----------------|
| Server URL  | `http://localhost:8080` | sessionStorage |
| Access token| —                       | sessionStorage |
| Device ID   | auto-generated UUID     | localStorage   |

Default master PIN (server-side): `070901` — see backend `settings.master_pin`.

## API usage (matches macOS client)

| Action              | Endpoint                          |
|---------------------|-----------------------------------|
| PIN unlock          | `POST /api/v1/auth/unlock`        |
| Clipboard history   | `GET /api/v1/clipboard`           |
| Pin/unpin clipboard | `POST /api/v1/clipboard/:id/pin`  |
| List files          | `GET /api/v1/files`               |
| Pin/unpin file      | `POST /api/v1/files/:id/pin`      |

Unlock body:

```json
{
  "pin": "…",
  "device_id": "uuid",
  "device_name": "Web Browser",
  "platform": "web"
}
```

## UI

- PIN unlock screen when no session token
- Clipboard tab: Temporary + Pinned sections with pin/unpin
- Files tab: Temporary + Pinned sections with pin/unpin
