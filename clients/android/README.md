# SyncBridge Android

Full Kotlin + Jetpack Compose client with Material 3, Outfit font, and background clipboard sync.

## Requirements

- Android Studio Ladybug (2024.2+) or CLI with **Android SDK 35**
- JDK 17+
- `local.properties` with `sdk.dir=/path/to/Android/sdk`

```properties
# clients/android/local.properties (not committed)
sdk.dir=/Users/you/Library/Android/sdk
```

## Project structure

```
clients/android/
├── app/
│   ├── build.gradle.kts
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── assets/fonts/Outfit-Variable.ttf
│       ├── java/com/syncbridge/android/
│       │   ├── MainActivity.kt
│       │   ├── SyncBridgeApp.kt
│       │   ├── data/          # ApiClient, FileUploader
│       │   ├── sync/          # Foreground service, WebSocket
│       │   ├── ui/            # Compose screens + theme
│       │   └── util/
│       └── res/
├── build.gradle.kts
├── settings.gradle.kts
└── gradlew
```

## Features

| Feature | Implementation |
|---------|----------------|
| PIN unlock | `ApiClient.unlock()` → trusted device 7 days |
| Clipboard sync | `SyncClipboardService` + `OnPrimaryClipChangedListener` |
| WebSocket | `WSClient` → `wss://api…/ws` |
| Quick Send | Camera / Gallery / Files + text on Clipboard tab |
| Share Sheet | `ACTION_SEND` / `SEND_MULTIPLE` in `MainActivity` |
| Dark mode | Material 3 + system theme |
| Material You | Dynamic color with teal primary override |

Default API URL: `https://api.sync.abhiraj.xyz` (PIN `070901`).

## Build commands

From `clients/android/`:

```bash
./gradlew assembleDebug      # Debug APK
./gradlew assembleRelease    # Release APK (signed with debug key by default)
./gradlew bundleRelease      # Play Store AAB
```

## Output paths

| Artifact | Path |
|----------|------|
| Debug APK | `app/build/outputs/apk/debug/app-debug.apk` |
| Release APK | `app/build/outputs/apk/release/app-release.apk` |
| Release AAB | `app/build/outputs/bundle/release/app-release.aab` |

## Release signing (production)

Create `keystore.properties` and configure `signingConfigs` in `app/build.gradle.kts` before publishing to Play Store.

## Permissions

- `INTERNET` — API + WebSocket
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_DATA_SYNC` — background sync
- `POST_NOTIFICATIONS` — sync + clipboard notifications (Android 13+)
- `CAMERA` — optional, for Take Photo

## Design system

Matches web: Outfit font, teal primary (`#0D9488`), indigo secondary, slate neutrals, shared spacing/radius tokens in `ui/theme/DesignTokens.kt`.
