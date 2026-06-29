/**
 * SyncBridge shared component contracts.
 * TypeScript interfaces define the API every platform must implement.
 * @see shared/design-system.md
 */

import type { ReactNode } from "react";

// ── Primitives ────────────────────────────────────────────────────────────────

export type ButtonVariant = "primary" | "secondary" | "ghost" | "danger";
export type ButtonSize = "sm" | "md" | "lg";

export interface AppButtonProps {
  variant?: ButtonVariant;
  size?: ButtonSize;
  block?: boolean;
  loading?: boolean;
  disabled?: boolean;
  children: ReactNode;
  onClick?: () => void;
}

export interface AppCardProps {
  hero?: boolean;
  interactive?: boolean;
  children: ReactNode;
}

export interface AppSectionTitleProps {
  title: string;
}

export interface AppEmptyStateProps {
  icon: ReactNode;
  title: string;
  description: string;
}

// ── Forms ─────────────────────────────────────────────────────────────────────

export interface LoginPinFieldProps {
  value: string;
  onChange: (value: string) => void;
  error?: string;
}

export interface SearchFieldProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
}

// ── Domain cards ──────────────────────────────────────────────────────────────

export interface DeviceCardProps {
  name: string;
  platform: string;
  online?: boolean;
  connectionQuality?: string;
  selected?: boolean;
  onClick?: () => void;
}

export interface TransferFileProgress {
  name: string;
  percent: number;
  transferred?: number;
  size?: number;
}

export type TransferPhase =
  | "idle"
  | "connecting"
  | "waitingAccept"
  | "transferring"
  | "paused"
  | "completed"
  | "failed";

export interface TransferCardProps {
  direction: "sending" | "receiving";
  peerName: string;
  phase: TransferPhase | string;
  percent: number;
  speedLabel: string;
  detailLabel: string;
  files: TransferFileProgress[];
  error?: string;
  onCancel?: () => void;
  onOpenFolder?: () => void;
  onSendMore?: () => void;
  onDone?: () => void;
}

export interface ClipboardCardProps {
  content: string;
  createdAt: string;
  pinned?: boolean;
  sourceDevice?: string;
  onCopy: () => void;
  onDelete?: () => void;
  onPin?: () => void;
}

// ── Overlays ──────────────────────────────────────────────────────────────────

export interface AppModalProps {
  title: string;
  message: string;
  confirmText: string;
  dismissText?: string;
  destructive?: boolean;
  onConfirm: () => void;
  onDismiss: () => void;
}

export interface BottomSheetProps {
  open: boolean;
  title?: string;
  onClose: () => void;
  children: ReactNode;
}

// ── Navigation ────────────────────────────────────────────────────────────────

export interface SegmentedTabsProps {
  options: string[];
  selectedIndex: number;
  onSelect: (index: number) => void;
}

export interface DockItem {
  id: string;
  label: string;
  icon: string;
}

export interface DockBottomBarProps {
  items: DockItem[];
  currentId: string;
  fabId?: string;
  onNavigate: (id: string) => void;
}

export interface AppShellProps {
  activeTab: string;
  onNavigate: (tab: string) => void;
  topBar?: AppTopBarProps;
  children: unknown;
}

// ── Status ────────────────────────────────────────────────────────────────────

export type TransferRoute = "cloud" | "directLan" | "webrtc";

export interface TransferBadgeProps {
  route: TransferRoute;
}

export type StatusChipState = "online" | "offline" | "syncing" | "connected" | "disconnected";

export interface StatusChipProps {
  state: StatusChipState;
  label?: string;
}

// ── Loading ───────────────────────────────────────────────────────────────────

export interface SkeletonProps {
  rows?: number;
}

export interface ProgressIndicatorProps {
  value: number;
  indeterminate?: boolean;
}
