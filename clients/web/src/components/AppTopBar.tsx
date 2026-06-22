import { AppBrand } from "./AppBrand";
import { ConnectionStatusPopover } from "./ConnectionStatusPopover";
import { IconMoon, IconSun } from "./Icons";
import { useTheme } from "../design/ThemeProvider";

interface Props {
  connected?: boolean;
}

export function AppTopBar({ connected }: Props) {
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
    <header className="ds-topbar">
      <AppBrand size="sm" />
      <div className="ds-topbar-actions">
        {connected !== undefined && <ConnectionStatusPopover connected={connected} />}
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
