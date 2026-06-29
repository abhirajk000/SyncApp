/**
 * Canonical navigation model — identical tabs on every platform.
 */

export const NAV_TABS = [
  { id: "clipboard", label: "Clipboard", icon: "clipboard", fab: false },
  { id: "pinned", label: "Pinned", icon: "pin", fab: false },
  { id: "send", label: "Send", icon: "send", fab: true },
  { id: "files", label: "Files", icon: "folder", fab: false },
  { id: "settings", label: "Settings", icon: "settings", fab: false },
] as const;

export type NavTabId = (typeof NAV_TABS)[number]["id"];

export const DOCK_LEFT: NavTabId[] = ["clipboard", "pinned"];
export const DOCK_RIGHT: NavTabId[] = ["files", "settings"];
export const DOCK_FAB: NavTabId = "send";

export const ShellLayout = {
  headerHeight: 64,
  dockHeight: 66,
  dockFabSize: 60,
  dockFabOffset: -8,
  contentMaxWidth: 720,
  floatNavClearance: 108,
} as const;
