# UI Primitives

Structural layout and animation utilities shared across platforms.

| File | Purpose |
|------|---------|
| [`layout.ts`](./layout.ts) | Page structure, section, hero row contracts |
| [`animations.ts`](./animations.ts) | Duration/easing constants + web class map |
| [`web/primitives.css`](./web/primitives.css) | Web layout utility classes |
| [`index.ts`](./index.ts) | Barrel exports |

## Layout hierarchy (every screen)

```
Header (optional)
  ↓
Primary content (PageStack)
  ↓
Secondary content
  ↓
Navigation (Dock / Sidebar)
```

## Web usage

```css
@import "../../../../shared/theme/web/tokens.css";
@import "../../../../shared/ui/web/primitives.css";
```

```tsx
<div className="sb-page-stack">
  <section className="sb-section">...</section>
</div>
```

## Animation usage (Web)

```tsx
import { WebAnimationClasses } from "@syncbridge/shared/ui";

<div className={WebAnimationClasses.modalEnter}>...</div>
```

Allowed animation types: fade · scale · slide · sharedElement · progress · success · error

No custom durations outside `shared/theme/animations.json`.
