# SyncBridge — iOS Client (Stub)

Minimal SwiftUI scaffold for Phase D+E. Clipboard monitor and file transfer are not included yet.

## Requirements

| Tool   | Version |
|--------|---------|
| Xcode  | 15+     |
| iOS    | 16.0+   |
| Swift  | 5.9+    |

## Project setup

1. Xcode → **File → New → Project** → iOS App
2. Product Name: `SyncBridgeIOS`
3. Interface: SwiftUI · Language: Swift
4. Copy these files into the project (replace generated app entry if needed):

```
SyncBridgeIOSApp.swift   ← @main entry
LoginView.swift
AppState.swift
```

Delete auto-generated `ContentView.swift` if unused.

## Configuration

| Setting     | Default                 | Storage       |
|-------------|-------------------------|---------------|
| Server URL  | `http://localhost:8080` | UserDefaults  |
| Device ID   | auto-generated UUID     | UserDefaults  |
| Tokens      | —                       | UserDefaults  |

Default master PIN (server-side): `070901`.

For Simulator → local backend, `http://localhost:8080` works when the API runs on the same Mac.

## PIN unlock

`LoginView` calls `POST /api/v1/auth/unlock` with `platform: "ios"` — same pattern as the macOS client.

```json
{
  "pin": "…",
  "device_id": "uuid",
  "device_name": "iPhone (iOS)",
  "platform": "ios"
}
```

## Next steps (Phase D+E)

- Clipboard history: Temporary + Pinned sections
- `POST /api/v1/clipboard/:id/pin`
- Files list: Temporary + Pinned sections
- `POST /api/v1/files/:id/pin`
- Keychain for tokens (replace UserDefaults in production)
