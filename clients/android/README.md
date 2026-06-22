# SyncBridge — Android Client (Stub)

Minimal Kotlin scaffold for Phase D+E. Full app (Compose UI, clipboard monitor, file transfer) is not included yet.

## Requirements

| Tool        | Version |
|-------------|---------|
| Android Studio | Hedgehog+ |
| Kotlin      | 1.9+    |
| minSdk      | 26      |

## Project setup

1. Open Android Studio → **New Project** → Empty Activity
2. Package name: `com.syncbridge.android`
3. Copy `AuthRepository.kt` into `app/src/main/java/com/syncbridge/android/auth/`

## Configuration

| Setting     | Default                 | Storage          |
|-------------|-------------------------|------------------|
| Server URL  | `http://localhost:8080` | SharedPreferences |
| Device ID   | auto-generated UUID     | SharedPreferences |
| Tokens      | —                       | SharedPreferences |

Default master PIN (server-side): `070901`.

For emulator testing against a local backend, use `http://10.0.2.2:8080` instead of `localhost`.

## PIN unlock pattern

```kotlin
val auth = AuthRepository(context)
auth.serverUrl = "http://10.0.2.2:8080"
val result = auth.unlock(pin = userPin, deviceName = "Pixel 8")
// result.accessToken → use as Bearer token on authenticated calls
```

Request body (matches macOS / web):

```json
{
  "pin": "…",
  "device_id": "uuid",
  "device_name": "Android Device",
  "platform": "android"
}
```

## Next steps (Phase D+E)

- Compose `LoginScreen` with PIN field
- Clipboard history with Temporary / Pinned sections
- `POST /api/v1/clipboard/:id/pin`
- Files list with Temporary / Pinned sections
- `POST /api/v1/files/:id/pin`
