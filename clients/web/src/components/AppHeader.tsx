import type { ReactNode } from "react";
import { AppBadge } from "./AppBadge";
import { AppIcon } from "./AppIcon";

interface Props {
  title: string;
  subtitle?: string;
  connected?: boolean;
  actions?: ReactNode;
}

export function AppHeader({ title, subtitle, connected, actions }: Props) {
  return (
    <header className="ds-header">
      <AppIcon size="sm" className="ds-header-icon" alt="" />
      <div style={{ flex: 1 }}>
        <h1 className="ds-title">{title}</h1>
        {subtitle && <p className="ds-subtitle">{subtitle}</p>}
      </div>
      {connected !== undefined && (
        <AppBadge status={connected ? "connected" : "disconnected"} />
      )}
      {actions}
    </header>
  );
}
