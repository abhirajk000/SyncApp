# Shared Design System

Cross-platform foundation for SyncBridge UI.

| Path | Contents |
|------|----------|
| [`design-system.md`](./design-system.md) | **Master documentation** |
| [`theme/`](./theme/) | Tokens, animations, CSS variables |
| [`components/`](./components/) | API contracts + component catalog |
| [`ui/`](./ui/) | Layout primitives + animation utilities |

## Quick start

```bash
# Validate tokens
./scripts/sync-design-tokens.sh
```

## Web import

```css
@import "../../../../shared/theme/web/tokens.css";
@import "../../../../shared/theme/web/animations.css";
@import "../../../../shared/ui/web/primitives.css";
```

## TypeScript contracts

```ts
import type { DeviceCardProps, TransferCardProps } from "../../shared/components";
import { WebAnimationClasses } from "../../shared/ui";
```
