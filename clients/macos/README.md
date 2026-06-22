# SyncBridge — macOS Menu Bar App

A lightweight macOS menu bar application for universal clipboard sync and file transfer.

## Requirements

| Tool    | Version |
|---------|---------|
| Xcode   | 15+     |
| macOS   | 13.0+   |
| Swift   | 5.9+    |

No third-party Swift Package Manager dependencies — the app uses only Apple frameworks.

---

## Project Setup in Xcode

### 1. Create the Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose **macOS → App**
3. Fill in:
   - **Product Name:** `SyncBridgeMac`
   - **Bundle Identifier:** `com.syncbridge.mac`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Use Core Data:** ✗
4. Click **Next** and choose a location.

### 2. Add source files

Drag all files from this folder into the Xcode project navigator, preserving the group structure:

```
SyncBridgeMac/
├── App/
│   ├── SyncBridgeMacApp.swift
│   └── AppDelegate.swift
├── Core/
│   ├── API/
│   │   ├── APIClient.swift
│   │   └── AuthService.swift
│   ├── Clipboard/
│   │   └── ClipboardMonitor.swift
│   ├── FileTransfer/
│   │   └── FileTransferService.swift
│   ├── Storage/
│   │   └── KeychainService.swift
│   ├── Sync/
│   │   ├── AppState.swift
│   │   └── LoginItemService.swift
│   └── WebSocket/
│       └── WSClient.swift
├── MenuBar/
│   └── MenuBarView.swift
├── Models/
│   └── Models.swift
├── Views/
│   ├── ClipboardHistoryView.swift
│   ├── LoginView.swift
│   ├── PairingView.swift
│   └── SettingsView.swift
└── Resources/
    ├── Info.plist              ← replaces the generated one
    └── SyncBridgeMac.entitlements
```

> **Important:** Delete the auto-generated `ContentView.swift` and `SyncBridgeMacApp.swift` that Xcode creates — they are replaced by the files in this folder.

### 3. Configure the target

Select the **SyncBridgeMac** target → **General** tab:

| Field              | Value          |
|--------------------|----------------|
| Deployment Target  | macOS 13.0     |
| Bundle Identifier  | com.syncbridge.mac |
| Version            | 1.0            |
| Build              | 1              |

### 4. Set the custom Info.plist

Select **Build Settings** → search for **`Info.plist`**:

- **Info.plist File:** `SyncBridgeMac/Resources/Info.plist`
- **Generate Info.plist file:** OFF (if shown)

### 5. Configure entitlements

Select **Signing & Capabilities**:

1. Click **+ Capability** → add **Keychain Sharing**
   - Keychain Group: `com.syncbridge`
2. Set **Entitlements File** to `SyncBridgeMac/Resources/SyncBridgeMac.entitlements`
   (Build Settings → search `CODE_SIGN_ENTITLEMENTS`)
3. Enable **Hardened Runtime** → check:
   - ✅ Network Client
   - ✅ User Selected File (read/write)
   - ✅ Downloads folder (read/write)

### 6. (Optional) Launch-at-login helper — macOS 12 only

macOS 13+ uses `SMAppService` automatically — no extra setup needed.

For macOS 12 support, create a **macOS App Extension** target named `SyncBridgeMacLoginHelper` and register it via `SMLoginItemSetEnabled`. The bundle ID must be `com.syncbridge.mac.LoginHelper`.

---

## Building & Running

```bash
# Command line (no code signing for local testing)
xcodebuild -scheme SyncBridgeMac -configuration Debug build \
  CODE_SIGNING_ALLOWED=NO
```

Or press **⌘R** in Xcode.

---

## Architecture

```
SyncBridgeMacApp (@main)
 └─ AppDelegate (NSObject, NSApplicationDelegate)
      ├─ NSStatusItem + NSPopover  ← menu bar icon
      ├─ AppState (@MainActor ObservableObject)
      │    ├─ APIClient            ← URLSession REST
      │    ├─ AuthService          ← login/register/device reg
      │    ├─ WSClient             ← URLSessionWebSocketTask + reconnect
      │    ├─ ClipboardMonitor     ← NSPasteboard polling @ 500 ms
      │    └─ FileTransferService  ← chunked upload/download
      └─ SwiftUI views via NSHostingController
```

### Memory profile (idle)

| Component           | Approx. RSS |
|---------------------|-------------|
| Swift runtime       | ~8 MB       |
| AppKit / SwiftUI    | ~6 MB       |
| URLSession          | ~2 MB       |
| Application code    | ~4 MB       |
| **Total idle**      | **~20 MB**  |

Well under the 30 MB target.

### Clipboard monitoring

- Polls `NSPasteboard.general.changeCount` every **500 ms** on a background `DispatchSourceTimer`.
- Content is SHA-256 hashed before sync — no duplicate pushes.
- Echo suppression: writes from remote clipboard.new events set a 500 ms cooldown.
- macOS 14+ shows a one-time system permission prompt for background clipboard access.

### WebSocket reconnect strategy

| Attempt | Delay |
|---------|-------|
| 1       | 1 s   |
| 2       | 2 s   |
| 3       | 4 s   |
| 4       | 8 s   |
| 5+      | 60 s  |

`NWPathMonitor` resets the backoff immediately when the network becomes available.

### File transfer routing

| Condition           | mode     | Path                          |
|---------------------|----------|-------------------------------|
| Any network         | relay    | Chunked HTTP → server → relay |
| Same LAN (Phase 8)  | webrtc   | P2P DataChannel via signaling |

Phase 7 uses relay mode by default.  The `transfer_mode = "webrtc"` path for full peer-to-peer DataChannel transfer is wired up in the signaling layer and will be activated in Phase 8.

---

## Environment variables / Configuration

All configuration is stored in the macOS Keychain under group `com.syncbridge`.

| Key         | Default                | Description              |
|-------------|------------------------|--------------------------|
| Server URL  | `http://localhost:8080`| SyncBridge API endpoint  |

Change the server URL in **Settings → Server → Server URL**.

---

## Supported content types (clipboard)

| Type          | Content-Type    |
|---------------|-----------------|
| Plain text    | text/plain      |
| URLs          | text/uri-list   |
| Rich text     | text/html       |

## Supported file types (transfer)

Images (JPEG/PNG/GIF/WebP), Videos (MP4/MOV/WebM), Documents (PDF/DOCX/XLSX/PPTX), Archives (ZIP/GZ/TAR/7z), Plain text.
