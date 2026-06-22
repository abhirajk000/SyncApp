import type { ReactNode } from "react";
import { AppBadge } from "./AppBadge";

interface Props {
  title: string;
  subtitle?: string;
  connected?: boolean;
  actions?: ReactNode;
}

export function AppHeader({ title, subtitle, connected, actions }: Props) {
  return (
    <header className="ds-header">
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
