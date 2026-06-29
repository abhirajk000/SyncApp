# Theme

Canonical design tokens for all SyncBridge clients.

| File | Purpose |
|------|---------|
| [`tokens.json`](./tokens.json) | **Source of truth** — colors, typography, spacing, radius, shadows, layout |
| [`tokens.schema.json`](./tokens.schema.json) | JSON Schema validation |
| [`animations.json`](./animations.json) | Animation durations, easings, named presets |
| [`platforms.json`](./platforms.json) | Maps tokens → per-platform implementation paths |
| [`web/tokens.css`](./web/tokens.css) | CSS custom properties for Web |
| [`web/animations.css`](./web/animations.css) | Keyframes + animation utility classes |

## Sync workflow

```bash
./scripts/sync-design-tokens.sh
```

Validates `tokens.json` and prints platform drift warnings.

## Rules

1. **Never** edit platform token files without updating `tokens.json` first.
2. Run the sync script before merging UI changes.
3. Web imports CSS from here — not duplicated in `clients/web/`.
