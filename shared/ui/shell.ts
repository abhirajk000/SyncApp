/**
 * AppShell contract — every authenticated screen uses this structure.
 * @see shared/design-system.md#layout-primitives
 */

import type { NavTabId } from "./navigation";
import { ShellLayout } from "./navigation";

export { ShellLayout };

export interface AppTopBarProps {
  connected?: boolean;
  refreshing?: boolean;
  onRefresh?: () => void;
  onConnectionInfo?: () => void;
}

export interface AppShellProps {
  activeTab: NavTabId;
  onNavigate: (tab: NavTabId) => void;
  topBar: AppTopBarProps;
  children: unknown;
  /** Sub-page (e.g. settings → devices) keeps settings tab highlighted */
  navigationTab?: NavTabId;
}

/** Standard shell regions */
export type ShellRegion = "background" | "topBar" | "content" | "bottomNav";

export const ShellStructure = {
  regions: ["background", "topBar", "content", "bottomNav"] as ShellRegion[],
  topBar: { height: ShellLayout.headerHeight, glass: true },
  bottomNav: { height: ShellLayout.dockHeight, floating: true, glass: true },
  content: { padding: 16, maxWidth: ShellLayout.contentMaxWidth },
  pageTransition: { duration: 250, easing: "out" as const },
} as const;
