import { Clipboard, Folder, Pin, Send, Settings, type LucideIcon } from "lucide-react";

export type NavId = "clipboard" | "pinned" | "send" | "files" | "settings";

interface NavItem {
  id: NavId;
  label: string;
  Icon: LucideIcon;
}

const LEFT: NavItem[] = [
  { id: "clipboard", label: "Clipboard", Icon: Clipboard },
  { id: "pinned", label: "Pinned", Icon: Pin },
];

const RIGHT: NavItem[] = [
  { id: "files", label: "Files", Icon: Folder },
  { id: "settings", label: "Settings", Icon: Settings },
];

interface Props {
  active: NavId;
  onNavigate: (id: NavId) => void;
}

const DOCK_PATH =
  "M36 64 C18 64 4 50 4 32 V22 C4 10 14 0 26 0 H148 C162 0 172 3 178 8 C186 16 196 21 210 24.5 C224 21 234 16 242 8 C248 3 258 0 272 0 H394 C406 0 416 10 416 22 V32 C416 50 402 64 384 64 H36 Z";

interface ItemProps {
  item: NavItem;
  active: boolean;
  onNavigate: (id: NavId) => void;
}

function DockItem({ item, active, onNavigate }: ItemProps) {
  const { Icon } = item;
  return (
    <button
      type="button"
      className={`ds-dock-nav__item ${active ? "ds-dock-nav__item--active" : ""}`}
      onClick={() => onNavigate(item.id)}
      aria-current={active ? "page" : undefined}
    >
      <span className="ds-dock-nav__icon">
        <Icon size={22} strokeWidth={1.75} />
      </span>
      <span className="ds-dock-nav__label">{item.label}</span>
    </button>
  );
}

export function AppBottomNav({ active, onNavigate }: Props) {
  return (
    <nav className="ds-dock-nav" aria-label="Main navigation">
      <div className="ds-dock-nav__frame">
        <div className="ds-dock-nav__bar">
          <svg className="ds-dock-nav__shape" viewBox="0 0 420 64" preserveAspectRatio="none" aria-hidden>
            <defs>
              <linearGradient id="ds-dock-bar-fill" x1="0%" y1="0%" x2="0%" y2="100%">
                <stop offset="0%" stopColor="rgba(28, 34, 50, 0.88)" />
                <stop offset="100%" stopColor="rgba(12, 16, 28, 0.94)" />
              </linearGradient>
              <linearGradient id="ds-dock-bar-stroke" x1="0%" y1="0%" x2="0%" y2="100%">
                <stop offset="0%" stopColor="rgba(255,255,255,0.14)" />
                <stop offset="100%" stopColor="rgba(255,255,255,0.05)" />
              </linearGradient>
            </defs>
            <path d={DOCK_PATH} fill="url(#ds-dock-bar-fill)" stroke="url(#ds-dock-bar-stroke)" strokeWidth="1" />
          </svg>
          <div className="ds-dock-nav__blur" aria-hidden />
          <div className="ds-dock-nav__row">
            <div className="ds-dock-nav__group ds-dock-nav__group--left">
              {LEFT.map((item) => (
                <DockItem
                  key={item.id}
                  item={item}
                  active={active === item.id}
                  onNavigate={onNavigate}
                />
              ))}
            </div>
            <div className="ds-dock-nav__slot" aria-hidden />
            <div className="ds-dock-nav__group ds-dock-nav__group--right">
              {RIGHT.map((item) => (
                <DockItem
                  key={item.id}
                  item={item}
                  active={active === item.id}
                  onNavigate={onNavigate}
                />
              ))}
            </div>
          </div>
        </div>

        <button
          type="button"
          className={`ds-dock-nav__fab ${active === "send" ? "ds-dock-nav__fab--active" : ""}`}
          onClick={() => onNavigate("send")}
          aria-label="Send"
          aria-current={active === "send" ? "page" : undefined}
        >
          <span className="ds-dock-nav__fab-glow" aria-hidden />
          <Send size={24} strokeWidth={2} />
        </button>
      </div>
    </nav>
  );
}

export function AppLayout({ children }: { children: React.ReactNode }) {
  return <div className="ds-shell">{children}</div>;
}
