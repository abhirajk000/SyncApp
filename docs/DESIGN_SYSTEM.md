# SyncBridge Design System

Single unified design language across all clients.

## Tokens

| Token | Value |
|-------|-------|
| Font | **Outfit** (web); SF Rounded (Apple fallback) |
| Primary | Teal `#0d9488` |
| Secondary | Indigo `#4f46e5` |
| Success | Green |
| Warning | Amber |
| Danger | Red |
| Neutral | Slate |
| Spacing | 4 / 8 / 12 / 16 / 24 / 32 / 48px |
| Radius | sm 6px · md 10px · lg 16px |
| Shadow | sm / md / lg (subtle) |

## Web (`clients/web/src/`)

**Tokens:** `design/tokens.css` · **Components CSS:** `design/components.css`  
**React components:** `components/` — `AppButton`, `AppInput`, `AppCard`, `AppModal`, `AppBadge`, `AppTabs`, `AppHeader`, `AppSidebar`, `AppLayout`, `AppEmptyState`, `AppStatCard`, `AppSection`, `AppSkeleton`  
**Providers:** `ThemeProvider` (light/dark/system), `ToastProvider`

## Swift

- macOS: `clients/macos/SyncBridgeMac/Design/DesignSystem.swift`
- iOS: `clients/ios/DesignSystem.swift`

---

## Final audit (web)

| Screen | Status |
|--------|--------|
| Unlock (`LoginPage`) | ✅ |
| Dashboard | ✅ |
| Clipboard | ✅ skeleton + empty state |
| Pinned | ✅ same as Clipboard |
| Files | ✅ |
| Images | ✅ empty state |
| Devices | ✅ empty state |
| Settings | ✅ theme toggle |
| Latest clipboard modal | ✅ `AppModal` |
| Toasts | ✅ |
| Loading | ✅ skeletons (no spinners) |

## Final audit (macOS)

| Screen | Status |
|--------|--------|
| LoginView | ✅ |
| MenuBar header + tabs | ✅ |
| ClipboardHistory | ✅ empty state + sections |
| Files tab | ✅ empty state + `AppButton` |
| Devices tab | ✅ empty state |
| PairingView | ✅ |
| LatestClipboardPopup | ✅ |
| SettingsView | ✅ tint + grouped form (native shell) |

## Final audit (iOS)

| Screen | Status |
|--------|--------|
| LoginView | ✅ |
| LatestClipboardView | ✅ |
| Main shell | ⚠️ placeholder — apply `AppCard` shell when built |

## Android (`clients/android/app/`)

| Screen | Status |
|--------|--------|
| Login / PIN unlock | ✅ |
| Clipboard (Quick Send + Latest + History) | ✅ |
| Pinned / Files / Images / Settings | ✅ |
| Foreground sync + WebSocket | ✅ |
| Share Sheet | ✅ |
| Outfit + Material You theme | ✅ |

---

## Remaining gaps

1. **iOS main navigation shell** — not yet a full tab layout matching web sidebar.
2. **macOS row views** (`ClipboardEntryRow`, `FileRowView`) — functional native rows; could adopt `DS.Font` on a follow-up pass.
3. **Outfit on Apple** — uses SF Rounded fallback; embed Outfit via custom font if pixel-perfect parity is required.

## Rule

No custom per-page styling outside `design/`, `components/`, and token-based inline spacing.
