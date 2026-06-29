# SyncBridge — Cross-Platform Design Audit

**Date:** 2026-06-29  
**Purpose:** Complete audit before Phase 1 (or any UI work).  
**Rule:** No platform or screen may be redesigned in isolation. Every change must be reviewed against **all** platforms.

**References:** `shared/design-system.md` · `shared/theme/tokens.json`

---

## Executive Summary

SyncBridge has a **coherent color palette and spacing foundation**, but **four separate UI implementations** that drift visually. Screenshots side-by-side today would **not** look like one premium product.

| Dimension | Web | Android | iOS / iPad | macOS | Aligned? |
|-----------|-----|---------|------------|-------|----------|
| Color palette | ✅ tokens.css | ✅ SyncTokens | ✅ SyncTokens | ⚠️ DS (duplicate) | Mostly |
| Typography (Outfit) | ✅ | ✅ bundled | ❌ SF Rounded | ❌ SF Rounded | **No** |
| Card radius (28px) | ❌ uses 20px | ❌ uses 20px | ❌ uses 20px | ❌ uses 20px | **No** |
| Button radius (20px) | ✅ fixed | ❌ uses 14px | ❌ uses 14px | ✅ fixed | Partial |
| Input radius (18px) | ✅ fixed | ❌ uses 14px | ❌ uses 14px | ✅ fixed | Partial |
| Shadow scale (4 levels) | ✅ CSS | ❌ ad-hoc | ❌ ad-hoc | ❌ ad-hoc | **No** |
| Shared DeviceCard | ❌ page-local | ❌ duplicated ×2 | ❌ custom | ❌ custom | **No** |
| Shared TransferCard | ❌ missing | ❌ missing | ❌ missing | ❌ missing | **No** |
| Shared ClipboardCard | ❌ missing | ❌ duplicated | ❌ duplicated | ❌ duplicated | **No** |
| Shared AppModal | ⚠️ partial | ❌ AlertDialog | ❌ custom overlay | ❌ custom overlay | **No** |
| Navigation pattern | Bottom dock | Bottom dock | Bottom dock | Top dock (popover) | Layout OK |
| Empty states | ✅ AppEmptyState | ⚠️ partial | ⚠️ partial | ⚠️ partial | Partial |
| Material Design leakage | None | **High** | Low | Low (native Form) | Android worst |

**iPad:** Same codebase as iOS (`TARGETED_DEVICE_FAMILY: 1,2`). No separate UI — iOS audit applies.

---

## Screen Inventory (All Platforms)

| Feature | Web | Android | iOS/iPad | macOS |
|---------|-----|---------|----------|-------|
| Login / PIN | LoginPage ✅ | LoginScreen ✅ | LoginView ✅ | LoginView ✅ |
| Home / Clipboard | HomePage | HomeScreen | HomeView | HomeView |
| Pinned | ClipboardPage | PinnedScreen | PinnedView | PinnedClipboardView |
| Send (Cloud) | SendPage | SendScreen | SendView | SendTabView |
| Send (Wi-Fi) | LocalSendPage | LocalSendScreen | LocalSendView | LocalSendView |
| Send hub | SendHubPage | MainShell tabs | SendSectionView | SendSectionView |
| Files | FilesPage | FilesScreen | FilesView | FilesView (in MenuBar) |
| Settings | SettingsPage | SettingsScreen | SettingsView | SettingsView |
| Devices | DevicesPage | DevicesScreen | DevicesView | DevicesView ⚠️ orphan |
| Network | NetworkPage ⚠️ orphan | NetworkScreen ⚠️ orphan | — | NetworkSettingsView |
| Latest clipboard popup | App.tsx modal | LatestClipboardDialog | LatestClipboardView | LatestClipboardPopupView |
| Shell / Nav | AppLayout + dock | MainShell + dock | MainShell + dock | MenuBarView + top dock |

**Orphan / dead screens (remove or wire):**
- Web: `DashboardPage`, `ImagesPage`, `NetworkPage`
- Android: `ClipboardScreen`, `NetworkScreen`
- macOS: `ClipboardHistoryView`, `DevicesView`

---

## Critical Issues (Block Phase 1 Until Planned)

### C1 — Typography: Outfit not used on Apple platforms
- **Spec:** Outfit 400/500/600/700 only
- **Actual:** iOS, iPad, macOS use SF Rounded / SF Pro everywhere
- **Impact:** Instant visual mismatch vs Web + Android
- **Fix:** Bundle `Outfit-Variable.ttf` in iOS/macOS targets; create `SyncFont` helper

### C2 — Card radius wrong everywhere (20px vs 28px)
- **Spec:** `radius.card` = 28px
- **Actual:** `AppCard`, `GlassListRow`, `.ds-card` all use 20px (`RadiusLg` / `--radius-lg`)
- **Impact:** Cards look smaller/less premium than spec
- **Fix:** Change foundational `AppCard` on all 4 platforms first — cascades everywhere

### C3 — Missing shared components (spec-required, built per-platform)
| Component | Web | Android | iOS | macOS |
|-----------|-----|---------|-----|-------|
| `DeviceCard` | page-local | ×2 private copies | custom inline | custom inline |
| `TransferCard` | missing | missing | missing | missing |
| `ClipboardCard` | missing | duplicated in Home | duplicated in Home | duplicated in Home |
| `AppModal` | partial | AlertDialog | custom overlay | custom overlay |

### C4 — Clipboard UI duplicated 4× instead of shared
- `AppComponents` (Android/iOS) defines `LatestTextCard`, `LatestImageCard`, `Earlier*Row` — **unused**
- `HomeScreen` / `HomeView` / `HomePage` each reimplement the same cards privately
- **Fix:** One shared component per platform; delete duplicates

### C5 — Android Material Design leakage
- Raw `OutlinedButton`, `Button`, `AlertDialog`, `TopAppBar`, `Scaffold`, `LinearProgressIndicator`, `Switch`
- Default M3 styling visible on Send, LocalSend, Devices, Settings, MainShell
- **Fix:** Route all through `PrimaryButton` / `GhostButton` / `AppModal`; custom progress components

---

## High-Severity Issues by Platform

### Android (10 screens, 14 components)

| Screen | Severity | Top violations |
|--------|----------|----------------|
| HomeScreen | **High** | Reimplements clipboard cards; raw Surface cards |
| LocalSendScreen | **High** | Local DeviceCard/TransferCard; Material buttons/dialogs |
| DevicesScreen | **High** | Local DeviceCard; AlertDialog; inline empty state |
| ClipboardScreen | **High** | Orphaned; Material Surface rows |
| AppComponents.kt | **High** | Wrong radii (card 20, button 14); foundational |
| DockBottomBar | **High** | Hardcoded FAB gradient colors |
| SendScreen | Medium | OutlinedButton; no TransferCard |
| FilesScreen | Medium | Hardcoded preview colors |
| SettingsScreen | Medium | Raw Material Button/Switch |
| MainShell | Medium | OutlinedButton mode toggle |
| LoginScreen | **Low** | Best compliance |

### iOS / iPad (11 screens + 11 components)

| Screen | Severity | Top violations |
|--------|----------|----------------|
| All screens | **Critical** | SF Rounded, not Outfit |
| AppComponents.swift | **High** | Wrong radii; unused duplicate cards |
| HomeView | **High** | Private HomeLatest* duplicates AppComponents |
| LocalSendView | **High** | Custom deviceCard/transferCard; .bordered buttons |
| DevicesView | **High** | Custom deviceCard; Color.gray; no AppEmptyState |
| SendSectionView | **High** | Native Picker instead of SegmentedTabs |
| DockBottomBar | **High** | Hardcoded layout values |
| TransferBadge | **High** | All colors hardcoded RGB |
| LoginView | Low | Best compliance (except font) |

### macOS (15 views + 4 design files)

| View | Severity | Top violations |
|------|----------|----------------|
| DesignSystem.swift | **High** | Standalone `DS` enum, not `SyncTokens`; SF Rounded |
| DockNavBar | **High** | ~15 inline colors; top dock vs bottom elsewhere |
| HomeView | **High** | Private clipboard cards |
| LocalSendView | **High** | Custom deviceCard |
| SettingsView | Medium | Native macOS Form (intentional but visually different) |
| FileRowView, TransferRowView | Medium | Legacy `.subheadline`/`.accentColor` |
| ClipboardHistoryView | Medium | Orphaned; legacy list styling |
| LoginView | Low | Good DS usage |

### Web (8 routed pages + 33 components)

| Page | Severity | Top violations |
|------|----------|----------------|
| LocalSendPage | **High** | Heavy inline styles; invalid `--color-muted` var |
| HomePage | **Medium** | Custom ds-home-glass-card instead of ClipboardCard |
| PinnedPage | **Medium** | Custom ds-list-item rows |
| DevicesPage | **Medium** | DeviceCard page-local, not shared export |
| `.ds-card` CSS | **High** | Uses 20px radius, not `--radius-card` (28px) |
| TransferBadge CSS | **Medium** | Hardcoded hex colors |
| LoginPage | **Low** | Best compliance |

---

## Cross-Platform Component Matrix

| Component | Web | Android | iOS | macOS | Identical? |
|-----------|-----|---------|-----|-------|------------|
| AppCard | ✅ `.ds-card` | ✅ | ✅ | ✅ | ❌ radius |
| PrimaryButton | ✅ AppButton | ✅ | ✅ | ✅ AppButton | ❌ radius/height |
| GhostButton | ✅ variant | ✅ | ✅ | ❌ ListGhostButton | ❌ |
| AppEmptyState | ✅ | ✅ | ✅ | ✅ | ⚠️ iOS wraps in card |
| GlassListRow | ❌ CSS only | ✅ | ✅ | ✅ | ❌ radius |
| SegmentedTabs | ❌ unused AppTabs | ✅ | ✅ | ❌ native Picker | ❌ |
| DockBottomBar | ✅ | ✅ | ✅ | ❌ top DockNavBar | ❌ position |
| AppTopBar | ✅ | ✅ TopAppBar | ✅ header | ✅ MenuBar header | ❌ heights |
| TransferBadge | ✅ | ✅ | ✅ | ✅ TransferBadgeView | ❌ hardcoded colors |
| ItemDeleteButton | ✅ | ✅ | ✅ | ✅ | ✅ similar |
| FileGridCard | ✅ | ✅ | ✅ | ✅ | ⚠️ grid min differs |
| LatestClipboardDialog | ✅ AppModal | ✅ Dialog | ✅ overlay | ✅ overlay | ❌ |
| DeviceCard | ❌ local | ❌ ×2 local | ❌ inline | ❌ inline | **❌** |
| TransferCard | ❌ | ❌ | ❌ | ❌ | **❌** |
| ClipboardCard | ❌ | ❌ | ❌ | ❌ | **❌** |
| AppModal | ✅ | ❌ | ❌ | ❌ | **❌** |
| BottomSheet | ❌ | ❌ | ❌ | ❌ | **❌** |
| SearchField | ❌ | ❌ | ❌ | ❌ | **❌** |
| Skeleton/Loading | ✅ | ❌ | ❌ | ❌ | **❌** |

---

## Token Drift Detail

| Token | Spec | Web | Android | iOS | macOS |
|-------|------|-----|---------|-----|-------|
| `radius.card` | 28 | 20 (--radius-lg) | 20 (RadiusLg) | 20 (radiusLg) | 20 (Radius.lg) |
| `radius.button` | 20 | 20 ✅ | 14 (RadiusMd) | 14 (radiusMd) | 20 ✅ |
| `radius.input` | 18 | 18 ✅ | 14 (RadiusMd) | 14 (radiusMd) | 18 ✅ |
| `typography.fontFamily` | Outfit | Outfit ✅ | Outfit ✅ | SF Rounded ❌ | SF Rounded ❌ |
| `typography.base` | 16px | 16px ✅ | 16px ✅ | 16px ✅ | 14px ❌ |
| `colors.background` dark | #080D18 | ✅ | ✅ | ✅ | ✅ (fixed) |
| `colors.textMuted` | #8B9BB5 | ✅ | ✅ | ✅ | ✅ (fixed) |
| `spacing` grid | 4–48 | ✅ +64 | ✅ | ✅ | ⚠️ missing 20,40,48 |
| `shadow.*` (4 levels) | defined | ✅ CSS | ❌ ad-hoc dp | ❌ ad-hoc | ❌ ad-hoc |
| `icon` sizes | 16–40 | ✅ | ✅ added | ✅ added | ✅ added |
| `animation` durations | 150–500ms | ✅ | ✅ added | ✅ added | ✅ added |

---

## Hardcoded Color Hotspots (Fix in All Platforms)

| Location | Colors | Should be |
|----------|--------|-----------|
| DockBottomBar (Android/iOS) | `#3B82F6`, `#6366F1`, `#7C3AED` FAB | `SyncTokens.Secondary` + `Accent` |
| TransferBadge (all) | `#2563eb`, `#15803d`, purples | `SyncTokens.Secondary`, `Success`, `Accent` |
| FilesScreen previews | `#64748B`, `#1E293B` | `TextMuted`, `TextPrimary` |
| ItemActionMenu overlay | `black 55%` | Tokenized overlay |
| DockNavBar (macOS) | ~15 inline RGB | `AppSurfaces.dock*` |

---

## Phase 0 — Prerequisite Work (Before Any Screen Redesign)

Execute in this order. **Do not skip steps.**

### Step 0.1 — Fix foundational components (all platforms, one PR)
1. `AppCard` → `radiusCard` (28px)
2. `PrimaryButton` / `AppButton` → `radiusButton` (20px)
3. `LoginPinField` / inputs → `radiusInput` (18px)
4. Web `.ds-card` → `var(--radius-card)`

### Step 0.2 — Bundle Outfit on Apple (one PR)
1. Copy `Outfit-Variable.ttf` to iOS + macOS resources
2. Create `SyncFont` helper mapping token sizes → Outfit weights
3. Replace all `.system(..., design: .rounded)` calls

### Step 0.3 — Create missing shared components (all platforms, one PR each)
1. `DeviceCard` — used by LocalSend, Devices, TrustedDevicesBar
2. `TransferCard` — used by LocalSend, Send upload progress
3. `ClipboardCard` — used by Home, Pinned; delete all duplicates
4. `AppModal` — replace AlertDialog / custom overlays

### Step 0.4 — Unify token API on macOS
1. Replace `enum DS` with `SyncTokens` + `AppSurfaces` (mirror iOS)
2. `typealias DS = SyncTokens` for backward compat during migration

### Step 0.5 — Remove dead screens
- Delete or wire: ClipboardScreen, NetworkScreen (Android); NetworkPage, DashboardPage, ImagesPage (Web); ClipboardHistoryView, DevicesView (macOS)

### Step 0.6 — Android Material purge
- Replace all raw `Button`/`OutlinedButton`/`AlertDialog` with design-system components
- Disable dynamic color override on API 31+ (or lock to SyncTokens)

---

## Phase 1 Gate Checklist

Before starting Phase 1 (Local Send redesign or any feature UI):

- [x] Step 0.1 complete — foundational radii fixed on all 4 platforms
- [x] Step 0.2 complete — Outfit on iOS/iPad/macOS
- [x] Step 0.3 complete — DeviceCard, TransferCard, ClipboardCard, AppModal exist on all platforms
- [x] Step 0.4 complete — macOS uses SyncTokens (DS.Font → SyncFont; radii aligned)
- [x] Step 0.5 complete — dead screens removed
- [x] Step 0.6 complete — Android Material purge (Send/Devices/LocalSend/MainShell)
- [ ] Side-by-side screenshot review: Login, Home, LocalSend, Settings on all 4 platforms
- [ ] No screen uses hardcoded colors outside SyncTokens
- [ ] No screen invents custom card/button styles

**Only after all boxes checked → proceed to Phase 1.**

---

## Quality Target Reminder

The final experience should feel comparable to:
**Apple apps · Arc Browser · Linear · Raycast · Notion Calendar · Dropbox · Craft · LocalSend**

Not like a standard Material Design or basic CRUD application.

This rule applies to **every phase** of development.
