# Component Library

Cross-platform component catalog. Every component listed here **must exist on all four platforms** with matching visuals and equivalent APIs.

Contracts: [`contracts.ts`](./contracts.ts) · Premium spec: [`PREMIUM.md`](./PREMIUM.md)

## Phase 3 — Premium Primitives

| Component | Contract | Web | Android | iOS | macOS |
|-----------|----------|-----|---------|-----|-------|
| `AppButton` / `PrimaryButton` | `AppButtonProps` | `AppButton.tsx` | `PremiumComponents.kt` | `PrimaryButton` | `AppButton` |
| `GhostButton` | `variant: ghost` | `AppButton` | `PremiumGhostButton` | `GhostButton` | `AppButton` |
| `DangerButton` | `variant: danger` | `AppButton` | `PremiumDangerButton` | `DestructiveFullWidthButton` | `AppButton` |
| `PremiumIconButton` | — | CSS `.ds-icon-btn` | `PremiumIconButton` | `PremiumIconButton` | `PremiumIconButton` |
| `AppInput` / `LoginPinField` | `LoginPinFieldProps` | `AppInput.tsx` | `PremiumTextField` | `LoginPinField` | `PremiumSearchField` + `SecureField` |
| `AppSearchField` | `SearchFieldProps` | `AppSearchField.tsx` | `PremiumSearchField` | `PremiumSearchField` | `PremiumSearchField` |
| `AppModal` | `AppModalProps` | `AppModal.tsx` | `PremiumAppModal` | `PremiumAppModalOverlay` | `PremiumAppModalOverlay` |
| `AppBottomSheet` | `BottomSheetProps` | `AppBottomSheet.tsx` | `PremiumBottomSheet` | `PremiumBottomSheet` | — |
| `AppChip` / `StatusChip` | `StatusChipProps` | `AppChip.tsx` | `PremiumChip` | `PremiumChip` | `PremiumChip` |
| `AppSkeleton` | `SkeletonProps` | `AppSkeleton.tsx` | `PremiumSkeleton` | `PremiumSkeleton` | `PremiumSkeleton` |
| `PremiumLinearProgress` | `ProgressIndicatorProps` | `.ds-progress` | `PremiumLinearProgress` | `PremiumLinearProgress` | `PremiumLinearProgress` |
| `AppEmptyState` | `AppEmptyStateProps` | `AppEmptyState.tsx` | `AppEmptyState.kt` | `AppEmptyState` | `AppEmptyState` |

**CSS:** `shared/theme/web/premium-components.css` (imported after `components.css`)

## Layout & Shell (Phase 2)

| Component | Web | Android | iOS | macOS |
|-----------|-----|---------|-----|-------|
| `AppShell` | `AppShell.tsx` | `AppShell.kt` | `AppShell.swift` | `AppShell.swift` |
| `AppTopBar` | `AppTopBar.tsx` | `AppTopBar.kt` | `AppTopBar.swift` | in `AppShell` |
| `DockBottomBar` | `AppBottomNav.tsx` | `DockBottomBar.kt` | `DockBottomBar.swift` | `DockBottomBar.swift` |

## Domain Cards

| Component | Contract | Web | Android | iOS | macOS |
|-----------|----------|-----|---------|-----|-------|
| `AppCard` | `AppCardProps` | `AppCard.tsx` | `AppComponents.kt` | `AppComponents.swift` | `DesignSystem.swift` |
| `DeviceCard` | `DeviceCardProps` | `DeviceCard.tsx` | `SharedCards.kt` | `SharedCards.swift` | `SharedCards.swift` |
| `TransferCard` | `TransferCardProps` | `TransferCard.tsx` | `SharedCards.kt` | `SharedCards.swift` | `SharedCards.swift` |
| `ClipboardCard` | `ClipboardCardProps` | `ClipboardCard.tsx` | `AppComponents.kt` | `AppComponents.swift` | `SharedCards.swift` |
| `TransferBadge` | `TransferBadgeProps` | CSS | `TransferBadge.kt` | `TransferBadge` | `TransferBadgeView` |
| `GlassListRow` | — | CSS `.ds-list-item` | `GlassListRow` | `GlassListRow` | `GlassListRow` |
| `SegmentedTabs` | `SegmentedTabsProps` | — | `SyncControls.kt` | `AppComponents.swift` | `DesignSystem.swift` |
| `ItemDeleteButton` | — | `ItemDeleteButton.tsx` | `ItemDeleteButton.kt` | `ItemActionMenu.swift` | `ItemActionMenu.swift` |

## Adding a component

1. Add interface to `contracts.ts`
2. Implement on **all four platforms** in the same PR
3. Update this catalog and `shared/design-system.md`
4. No Material / Bootstrap defaults — use `PREMIUM.md` spec
