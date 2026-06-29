# SyncBridge Design System

**Phase 1 deliverable** — Foundation & Design System  
**Version:** 4.0.0

Single source of truth for Android, iOS, iPad, macOS, Web, and future clients.

```
shared/
├── design-system.md      ← you are here
├── theme/
│   ├── tokens.json       ← machine-readable tokens
│   ├── animations.json   ← animation library
│   └── web/              ← CSS variables + keyframes
├── components/
│   ├── contracts.ts      ← component API contracts
│   └── catalog.md        ← implementation matrix
└── ui/
    ├── layout.ts         ← page structure primitives
    ├── animations.ts     ← typed animation presets
    └── web/primitives.css
```

---

## Product Philosophy

SyncBridge must feel like **one application**, not four different apps.

**Inspiration:** Apple HIG · Arc Browser · Linear · Raycast · Notion Calendar · LocalSend · AirDrop  
**Avoid:** Material Design · Bootstrap · random UI kits

---

## Rules (non-negotiable)

1. **Never** create a new button style, card style, color, shadow, or spacing value.
2. **Always** reuse shared components from `shared/components/`.
3. **No screen** may invent its own UI.
4. If a component changes, it changes **everywhere**.
5. Edit `shared/theme/tokens.json` first — then sync to platforms.

---

## Typography

| Rule | Value |
|------|-------|
| Font family | **Outfit** only |
| Weights | 400 · 500 · 600 · 700 |
| Never mix fonts | SF / Roboto / system fonts are **not** brand fonts |

| Role | Size | Weight | Token |
|------|------|--------|-------|
| Display | 40px | 700 | `typography.roles.display` |
| Title 2XL | 24px | 700 | `typography.roles.title2xl` |
| Title XL | 20px | 600 | `typography.roles.titleXl` |
| Title LG | 18px | 600 | `typography.roles.titleLg` |
| Body | 16px | 400 | `typography.roles.body` |
| Body SM | 14px | 400 | `typography.roles.bodySm` |
| Caption | 12px | 500 | `typography.roles.caption` |
| Label | 12px | 700 | `typography.roles.label` |

**Platform helpers:** `SyncFont` (iOS/macOS) · `Type.kt` (Android) · CSS vars (Web)

---

## Colors

Exact hex values from [`theme/tokens.json`](./theme/tokens.json).

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| Primary | `#0D9488` | `#2DD4BF` | CTAs, active states |
| Secondary | `#4F46E5` | `#818CF8` | Accents, gradients |
| Background | `#F4F7FB` | `#080D18` | Page background |
| Surface | `rgba(255,255,255,0.72)` | `rgba(17,24,39,0.72)` | Cards, glass |
| Text Primary | `#0C1222` | `#F1F5F9` | Headings, body |
| Text Secondary | `#5C6B82` | `#94A3B8` | Descriptions |
| Muted | `#8B9BB5` | `#64748B` | Hints, timestamps |
| Success | `#059669` | `#34D399` | Online, complete |
| Warning | `#D97706` | `#FBBF24` | Paused, caution |
| Danger | `#DC2626` | `#F87171` | Errors, offline |
| Accent | `#7C3AED` | `#A78BFA` | FAB, highlights |

Semantic colors (transfer badges, FAB gradient): `colors.semantic` in tokens.json

---

## Radius

| Element | Value | Token |
|---------|-------|-------|
| Cards / dialogs | **28px** | `radius.card` / `radius.dialog` |
| Buttons | **20px** | `radius.button` |
| Inputs | **18px** | `radius.input` |
| Chips / badges | **999px** | `radius.chip` |
| Small | 8px | `radius.sm` |
| Medium | 14px | `radius.md` |

---

## Shadows

Exactly **four** elevation levels.

| Level | Token | Use |
|-------|-------|-----|
| Small | `shadow.small` | List rows |
| Medium | `shadow.medium` | Standard cards |
| Large | `shadow.large` | Modals, hero cards |
| Floating | `shadow.floating` | Dock, FAB, popovers |

---

## Spacing

**8-point grid only:** 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48

| Token | px |
|-------|-----|
| `space.1` | 4 |
| `space.2` | 8 |
| `space.3` | 12 |
| `space.4` | 16 |
| `space.5` | 20 |
| `space.6` | 24 |
| `space.8` | 32 |
| `space.10` | 40 |
| `space.12` | 48 |

---

## Icons

| Size | px | Token |
|------|-----|-------|
| SM | 16 | `icon.sm` |
| MD | 20 | `icon.md` |
| Base | 24 | `icon.base` |
| LG | 28 | `icon.lg` |
| XL | 32 | `icon.xl` |
| 2XL | 40 | `icon.2xl` |

Platform icon families: Lucide (Web) · Material Outlined (Android) · SF Symbols (Apple)

---

## Animation Library

Defined in [`theme/animations.json`](./theme/animations.json).

| Duration | ms | Token |
|----------|-----|-------|
| Fast | 150 | `animation.duration.fast` |
| Normal | 250 | `animation.duration.normal` |
| Slow | 350 | `animation.duration.slow` |
| Slower | 500 | `animation.duration.slower` |

| Easing | Curve | Token |
|--------|-------|-------|
| Out | `cubic-bezier(0.22, 1, 0.36, 1)` | `animation.easing.out` |
| Liquid | `cubic-bezier(0.34, 1.2, 0.64, 1)` | `animation.easing.liquid` |
| In-out | `cubic-bezier(0.45, 0, 0.55, 1)` | `animation.easing.inOut` |

**Presets:** `fadeIn` · `slideUp` · `scaleIn` · `modalEnter` · `progressPulse` · `successPop` · `dockPress` · `liquidFloat`

Allowed types: fade · scale · slide · sharedElement · progress · success · error

---

## Layout Primitives

Every page follows the **AppShell** structure (Phase 2):

```
AppBackground (liquid gradient)
  └── AppTopBar (glass, 64px)
  └── Content (animated page transitions)
  └── DockBottomBar (floating glass, FAB center)
```

| Primitive | Web | Android | iOS | macOS |
|-----------|-----|---------|-----|-------|
| `AppShell` | `AppShell.tsx` | `AppShell.kt` | `AppShell.swift` | `AppShell.swift` |
| `AppTopBar` | `AppTopBar.tsx` | `AppTopBar.kt` | `AppTopBar.swift` | in `AppShell` |
| `DockBottomBar` | `AppBottomNav.tsx` | `DockBottomBar.kt` | `DockBottomBar.swift` | `DockBottomBar.swift` |

Shell spec: `shared/ui/shell.ts` · CSS: `shared/ui/web/shell.css`

| Primitive | Web class | Purpose |
|-----------|-----------|---------|
| PageStack | `.sb-page-stack` | Vertical page rhythm |
| Section | `.sb-section` | Titled content block |
| HeroRow | `.sb-hero-row` | Icon + title intro |
| ButtonGroup | `.sb-btn-group` | Modal / card actions |
| Overlay | `.sb-overlay` | Dimmed backdrop |
| Page enter | `.sb-page-enter` | Tab switch animation |

Layout tokens: `layout.headerHeight` (64) · `layout.dockHeight` (66) · `layout.maxContentWidth` (720)

**Navigation:** identical 5-tab dock on all platforms — Clipboard · Pinned · **Send (FAB)** · Files · Settings

---

**Phase 3 deliverable** — Premium Components (no Material / Bootstrap defaults)

Spec: [`components/PREMIUM.md`](./components/PREMIUM.md) · CSS: [`theme/web/premium-components.css`](./theme/web/premium-components.css)

| Primitive | All platforms use glass + token radii |
|-------------|---------------------------------------|
| Buttons | Teal gradient primary · ghost border · danger subtle |
| Inputs / Search | 18px radius · glass fill · focus ring |
| Dialogs | Custom overlay + scale-in (never `AlertDialog`) |
| Bottom sheets | Slide-up · drag handle · glass surface |
| Chips / Badges | Semantic pill colors |
| Skeletons | Shimmer bars (not spinners for lists) |
| Progress | 6px gradient bar |
| Domain cards | `DeviceCard` · `TransferCard` · `ClipboardCard` |

Android implementation: `PremiumComponents.kt` — wired through `AppComponents.kt` / `SharedCards.kt`.

---

**Phase 4 deliverable** — Visual Polish (beauty only)

Spec: [`components/POLISH.md`](./components/POLISH.md) · CSS: [`theme/web/visual-polish.css`](./theme/web/visual-polish.css)

| Effect | Implementation |
|--------|----------------|
| Liquid background | Drifting radial orbs · multi-stop gradients |
| Glassmorphism | 24px blur · inset highlight · saturate 1.35 |
| Floating cards | Liquid shadow + hover lift (web) |
| Press feedback | `scale(0.97)` on all platforms |
| Depth tiers | `sb-depth-1/2/3` · shadow-liquid/glow tokens |
| Empty states | `EmptyIllustration` · hero glass circle |
| Image placeholders | Shimmer gradient + sheen sweep |
| List enter | `sb-stagger` · 40ms cascade |

---

## Component Library

Full catalog: [`components/catalog.md`](./components/catalog.md)  
API contracts: [`components/contracts.ts`](./components/contracts.ts)

### Core components

| Component | Purpose |
|-----------|---------|
| `AppCard` | Standard content card (28px radius) |
| `AppButton` / `PrimaryButton` | Main CTA (20px radius) |
| `GhostButton` | Secondary / outline action |
| `AppEmptyState` | No content placeholder |
| `AppSectionTitle` | Uppercase section label |
| `GlassListRow` | Tappable list row |
| `DeviceCard` | Nearby / trusted device row |
| `TransferCard` | File transfer progress |
| `ClipboardCard` | Clipboard history item |
| `AppModal` | Confirmation / accept dialogs |
| `SegmentedTabs` | Cloud vs Wi-Fi toggle |
| `DockBottomBar` | Mobile navigation |
| `TransferBadge` | Cloud / LAN / WebRTC indicator |
| `LoginPinField` | PIN input (18px radius) |

### Device Card spec

- Platform emoji + system device name
- Online status · connection quality
- 28px radius · `shadow.small` · `space.4` padding
- Selected state: primary border at 50% opacity

### Transfer Card spec

- Direction + peer name + phase label
- Linear progress + speed + ETA
- Per-file progress rows
- Completed: Open Folder · Send More · Done

### Clipboard Card spec

- Text preview (3 lines max) or image thumb
- Relative timestamp
- Tap to copy · delete overlay button
- Pinned indicator when applicable

---

## Platform Mapping

| Concern | Canonical | Web | Android | iOS | macOS |
|---------|-----------|-----|---------|-----|-------|
| Tokens | `shared/theme/tokens.json` | `theme/web/tokens.css` | `SyncTokens` | `SyncTokens` | `DS` + `SyncFont` |
| Animations | `shared/theme/animations.json` | `theme/web/animations.css` | `SyncTokens.Duration*` | `SyncTokens.duration*` | `DS.Duration` |
| Components | `shared/components/contracts.ts` | `clients/web/src/components/` | `ui/components/` | `AppComponents.swift` | `Design/` |
| UI primitives | `shared/ui/` | `ui/web/primitives.css` | Compose layouts | SwiftUI stacks | SwiftUI stacks |

See [`theme/platforms.json`](./theme/platforms.json) for full file paths.

### Interaction conventions (visual identity never changes)

| Platform | Respect |
|----------|---------|
| Android | System back, notification channels |
| iOS | Swipe-back, haptics, Local Network prompt |
| macOS | Keyboard shortcuts, menu bar |
| Web | Hover states, Clipboard API gesture |

---

## Responsive

| Breakpoint | Layout |
|------------|--------|
| Phone | Single column, bottom dock |
| Tablet | Wider cards, same tokens |
| Desktop | Sidebar + content, same tokens |

Only layout changes. Colors, radius, shadows, typography stay identical.

---

## Workflow

### Adding a new token

1. Edit `shared/theme/tokens.json`
2. Run `./scripts/sync-design-tokens.sh`
3. Update platform implementations
4. Update this document

### Adding a new component

1. Add interface to `shared/components/contracts.ts`
2. Implement on all four platforms
3. Update `shared/components/catalog.md`
4. Never use screen-local implementations

---

## Success Criteria

Screenshots from Android, iOS, macOS, and Web side-by-side must look like the **same application**.

Only platform interaction differences should exist. Everything else is visually identical.

---

## Related docs

- [`docs/DESIGN_AUDIT.md`](../docs/DESIGN_AUDIT.md) — cross-platform audit + phase gates
- [`.cursor/rules/design-system.mdc`](../.cursor/rules/design-system.mdc) — agent rules
