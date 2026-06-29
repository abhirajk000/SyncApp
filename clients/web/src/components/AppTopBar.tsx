import { AppBrand } from "./AppBrand";
import { ConnectionStatusPopover } from "./ConnectionStatusPopover";
import { IconMoon, IconSun } from "./Icons";
import { useTheme } from "../design/ThemeProvider";
import { RefreshCw } from "lucide-react";

interface Props {
  connected?: boolean;
  refreshing?: boolean;
  onRefresh?: () => void;
}

export function AppTopBar({ connected, refreshing, onRefresh }: Props) {
  const { theme, setTheme } = useTheme();

  function toggleTheme() {
    if (theme === "dark") setTheme("light");
    else if (theme === "light") setTheme("dark");
    else {
      const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
      setTheme(prefersDark ? "light" : "dark");
    }
  }

  const showSun = theme === "dark";

    return (
    <header className="sb-topbar ds-topbar">
      <AppBrand size="sm" />
      <div className="ds-topbar-actions">
        {connected !== undefined && <ConnectionStatusPopover connected={connected} />}
        {onRefresh && (
          <button
            type="button"
            className="ds-topbar-icon-btn"
            onClick={onRefresh}
            disabled={refreshing}
            aria-label="Refresh sync"
          >
            <RefreshCw size={20} strokeWidth={2} className={refreshing ? "ds-spin" : ""} />
          </button>
        )}
        <button
          type="button"
          className="ds-topbar-icon-btn"
          onClick={toggleTheme}
          aria-label="Toggle theme"
        >
          {showSun ? <IconSun size={20} /> : <IconMoon size={20} />}
        </button>
      </div>
    </header>
  );
}
