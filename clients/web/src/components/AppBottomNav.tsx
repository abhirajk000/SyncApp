import {
  Clipboard,
  CloudUpload,
  Folder,
  Settings,
  Wifi,
  type LucideIcon,
} from "lucide-react";

export type NavId = "cloud_send" | "local_send" | "clipboard" | "files" | "settings";

interface NavItem {
  id: NavId;
  label: string;
  Icon: LucideIcon;
}

const LEFT: NavItem[] = [
  { id: "cloud_send", label: "Cloud Send", Icon: CloudUpload },
  { id: "local_send", label: "Local Send", Icon: Wifi },
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
      <span className="ds-dock-nav__pill">
        <span className="ds-dock-nav__icon">
          <Icon size={22} strokeWidth={active ? 2 : 1.75} />
        </span>
        <span className="ds-dock-nav__label">{item.label}</span>
      </span>
    </button>
  );
}

export function AppBottomNav({ active, onNavigate }: Props) {
  const clipboardActive = active === "clipboard";

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
          className={`ds-dock-nav__fab ds-dock-nav__fab--clipboard ${clipboardActive ? "ds-dock-nav__fab--active" : ""}`}
          onClick={() => onNavigate("clipboard")}
          aria-label="Clipboard"
          aria-current={clipboardActive ? "page" : undefined}
        >
          <span className="ds-dock-nav__fab-glow ds-dock-nav__fab-glow--teal" aria-hidden />
          <Clipboard size={26} strokeWidth={2} />
          {clipboardActive && (
            <span className="ds-dock-nav__fab-dots" aria-hidden>
              <span />
              <span className="ds-dock-nav__fab-dots--on" />
              <span />
            </span>
          )}
        </button>
      </div>
    </nav>
  );
}

export function AppLayout({ children }: { children: React.ReactNode }) {
  return <div className="ds-shell">{children}</div>;
}
