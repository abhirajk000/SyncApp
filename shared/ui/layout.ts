/**
 * SyncBridge layout primitives — structural building blocks for every screen.
 * @see shared/design-system.md#layout-primitives
 */

export const LayoutTokens = {
  headerHeight: 64,
  dockHeight: 66,
  bottomNavHeight: 72,
  sidebarWidth: 260,
  maxContentWidth: 720,
  pagePadding: 16,
  sectionGap: 32,
  cardGap: 16,
} as const;

export type PageRegion = "header" | "content" | "secondary" | "navigation";

export interface PageStructure {
  header?: boolean;
  primary: string;
  secondary?: string;
  navigation: "dock" | "sidebar" | "none";
}

/** Standard page stack — vertical rhythm for all screens */
export interface PageStackProps {
  gap?: keyof typeof import("../theme/tokens.json")["spacing"];
  children: unknown;
}

/** Section with optional title and action */
export interface SectionProps {
  title?: string;
  actionLabel?: string;
  onAction?: () => void;
  children: unknown;
}

/** Hero icon + title row (Local Send, feature intros) */
export interface HeroRowProps {
  icon: unknown;
  title: string;
  description?: string;
  gradient?: boolean;
}

/** Two-column action row (modal buttons, card footers) */
export interface ButtonGroupProps {
  align?: "start" | "end" | "stretch";
  children: unknown;
}

export const StandardPageStructure: PageStructure = {
  header: true,
  primary: "content",
  navigation: "dock",
};
