# Phase 4 — Visual Polish

Beauty only. No new features — depth, motion, and atmosphere.

## Atmosphere

| Layer | Treatment |
|-------|-----------|
| Page background | Multi-stop radial gradients + slow-drifting color orbs |
| Glass surfaces | 24px blur · saturate 1.35 · highlight inset · 72% white/dark fill |
| Depth | 3 elevation tiers — resting · raised · floating |

## Shadows

| Token | Use |
|-------|-----|
| `shadow.small` | List rows, chips |
| `shadow.medium` | Standard cards |
| `shadow.large` | Modals |
| `shadow.floating` | Dock, FAB, hover lift |
| `shadow.liquid` | Glass cards — soft + inset highlight |
| `shadow.glow` | Hero cards, primary CTAs |

## Motion

| Interaction | Behavior |
|-------------|----------|
| Hover (web/desktop) | `translateY(-2px)` + shadow upgrade |
| Press | `scale(0.97)` · 150ms ease-out |
| Page enter | Fade + slide up 10px |
| List stagger | 40ms delay per child |
| Background orbs | 22–26s liquid float loop |
| Modal | Scale 0.96 → 1 + fade |

## Cards

- **Floating card**: liquid shadow + 1px glass border + optional hover lift
- **Hero card**: gradient fill + primary glow shadow

## Empty states

- Glass card container · centered illustration (SVG) in hero circle
- Title + description + optional CTA
- Variants: `clipboard` · `files` · `send` · `devices` · `pinned` · `inbox`

## Image placeholders

- Shimmer gradient sweep · 28px radius · subtle glass border
- Never flat gray boxes

## CSS

`shared/theme/web/visual-polish.css` — imported after premium-components.css

## Platform files

| Platform | File |
|----------|------|
| Web | `visual-polish.css` · `EmptyIllustration.tsx` · `ImagePlaceholder.tsx` |
| Android | `VisualPolish.kt` · `Glass.kt` |
| iOS | `VisualPolish.swift` · `DesignSystem.swift` |
| macOS | `VisualPolish.swift` · `DesignSystem.swift` |
