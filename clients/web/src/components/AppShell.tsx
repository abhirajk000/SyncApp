import type { ReactNode } from "react";
import { AppBottomNav, type NavId } from "./AppBottomNav";
import { AppTopBar } from "./AppTopBar";

interface Props {
  activeTab: NavId;
  onNavigate: (id: NavId) => void;
  connected?: boolean;
  refreshing?: boolean;
  onRefresh?: () => void;
  children: ReactNode;
}

export function AppShell({
  activeTab,
  onNavigate,
  connected,
  refreshing,
  onRefresh,
  children,
}: Props) {
  return (
    <div className="sb-shell">
      <div className="sb-shell__main">
        <AppTopBar connected={connected} refreshing={refreshing} onRefresh={onRefresh} />
        <main key={activeTab} className="sb-shell__content sb-page-enter">
          <div className="sb-shell__content-inner">{children}</div>
        </main>
      </div>
      <div className="sb-shell__nav">
        <AppBottomNav active={activeTab} onNavigate={onNavigate} />
      </div>
    </div>
  );
}
