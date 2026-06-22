import type { ReactNode } from "react";
import {
  IconClipboard,
  IconFolder,
  IconPin,
  IconSend,
  IconSettings,
} from "./Icons";

export type NavId = "clipboard" | "pinned" | "send" | "files" | "settings";

interface NavItem {
  id: NavId;
  label: string;
  icon: ReactNode;
}

const LEFT: NavItem[] = [
  { id: "clipboard", label: "Clipboard", icon: <IconClipboard size={22} /> },
  { id: "pinned", label: "Pinned", icon: <IconPin size={22} /> },
];

const RIGHT: NavItem[] = [
  { id: "files", label: "Files", icon: <IconFolder size={22} /> },
  { id: "settings", label: "Settings", icon: <IconSettings size={22} /> },
];

interface Props {
  active: NavId;
  onNavigate: (id: NavId) => void;
}

function DockBarShape() {
  return (
    <svg
      className="ds-dock-nav__shape"
      viewBox="0 0 420 64"
      preserveAspectRatio="none"
      aria-hidden
    >
      <defs>
        <linearGradient id="ds-dock-bar-fill" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor="rgba(28, 34, 50, 0.96)" />
          <stop offset="100%" stopColor="rgba(14, 18, 30, 0.98)" />
        </linearGradient>
      </defs>
      <path
        d="M32 64
           C14.3 64 0 49.7 0 32
           V22
           C0 9.85 9.85 0 22 0
           H146
           C160 0 170 2.5 176 7
           C188 18.5 198 23 210 26.5
           C222 23 232 18.5 244 7
           C250 2.5 260 0 274 0
           H398
           C410.15 0 420 9.85 420 22
           V32
           C420 49.7 405.7 64 388 64
           H32
           Z"
        fill="url(#ds-dock-bar-fill)"
        stroke="rgba(110, 130, 170, 0.22)"
        strokeWidth="1"
      />
    </svg>
  );
}

interface ItemProps {
  item: NavItem;
  active: boolean;
  onNavigate: (id: NavId) => void;
}

function DockItem({ item, active, onNavigate }: ItemProps) {
  return (
    <button
      type="button"
      className={`ds-dock-nav__item ${active ? "ds-dock-nav__item--active" : ""}`}
      onClick={() => onNavigate(item.id)}
      aria-current={active ? "page" : undefined}
    >
      <span className="ds-dock-nav__icon">{item.icon}</span>
      <span className="ds-dock-nav__label">{item.label}</span>
    </button>
  );
}

export function AppBottomNav({ active, onNavigate }: Props) {
  return (
    <nav className="ds-dock-nav" aria-label="Main navigation">
      <div className="ds-dock-nav__frame">
        <div className="ds-dock-nav__bar">
          <DockBarShape />
          <div className="ds-dock-nav__row">
            {LEFT.map((item) => (
              <DockItem
                key={item.id}
                item={item}
                active={active === item.id}
                onNavigate={onNavigate}
              />
            ))}
            <div className="ds-dock-nav__slot" aria-hidden />
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

        <button
          type="button"
          className={`ds-dock-nav__fab ${active === "send" ? "ds-dock-nav__fab--active" : ""}`}
          onClick={() => onNavigate("send")}
          aria-label="Send"
          aria-current={active === "send" ? "page" : undefined}
        >
          <IconSend size={24} strokeWidth={2} />
        </button>
      </div>
    </nav>
  );
}

export function AppLayout({ children }: { children: React.ReactNode }) {
  return <div className="ds-shell">{children}</div>;
}
