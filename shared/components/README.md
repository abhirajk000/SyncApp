# Components

Shared component API contracts and catalog.

- [`contracts.ts`](./contracts.ts) — TypeScript interfaces (canonical API)
- [`catalog.md`](./catalog.md) — implementation matrix per platform

Platform implementations live in each client:

```
clients/web/src/components/
clients/android/.../ui/components/
clients/ios/AppComponents.swift + SharedCards.swift
clients/macos/SyncBridgeMac/Design/
```

Never build screen-local buttons, cards, or empty states. Import from the shared library.
