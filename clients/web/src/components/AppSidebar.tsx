import type { ReactNode } from "react";
import {
  IconClipboard,
  IconDashboard,
  IconDevices,
  IconFolder,
  IconImage,
  IconLogout,
  IconPin,
  IconSettings,
} from "./Icons";
import { AppBrand } from "./AppBrand";

export type NavId =
  | "dashboard"
  | "clipboard"
  | "pinned"
  | "files"
  | "images"
  | "devices"
  | "settings";

interface NavItem {
  id: NavId;
  label: string;
  icon: ReactNode;
  mobile?: boolean;
}

const NAV: NavItem[] = [
  { id: "dashboard", label: "Dashboard", icon: <IconDashboard size={20} /> },
  { id: "clipboard", label: "Clipboard", icon: <IconClipboard size={20} />, mobile: true },
  { id: "pinned", label: "Pinned", icon: <IconPin size={20} />, mobile: true },
  { id: "files", label: "Files", icon: <IconFolder size={20} />, mobile: true },
  { id: "images", label: "Images", icon: <IconImage size={20} /> },
  { id: "devices", label: "Devices", icon: <IconDevices size={20} />, mobile: true },
  { id: "settings", label: "Settings", icon: <IconSettings size={20} />, mobile: true },
];

const MOBILE_NAV = NAV.filter((n) => n.mobile);

interface Props {
  active: NavId;
  onNavigate: (id: NavId) => void;
  onLogout: () => void;
}

export function AppSidebar({ active, onNavigate, onLogout }: Props) {
  return (
    <>
      <aside className="ds-sidebar">
        <AppBrand />
        <nav className="ds-nav">
          {NAV.map((item) => (
            <button
              key={item.id}
              type="button"
              className={`ds-nav-item ${active === item.id ? "ds-nav-item--active" : ""}`}
              onClick={() => onNavigate(item.id)}
            >
              <span className="ds-nav-icon">{item.icon}</span>
              {item.label}
            </button>
          ))}
        </nav>
        <button type="button" className="ds-nav-item" onClick={onLogout} style={{ marginTop: "auto" }}>
          <span className="ds-nav-icon"><IconLogout size={20} /></span>
          Log out
        </button>
      </aside>

      <nav className="ds-bottom-nav" aria-label="Main navigation">
        {MOBILE_NAV.map((item) => (
          <button
            key={item.id}
            type="button"
            className={`ds-bottom-nav-item ${active === item.id ? "ds-bottom-nav-item--active" : ""}`}
            onClick={() => onNavigate(item.id)}
          >
            {item.icon}
            <span>{item.label}</span>
          </button>
        ))}
      </nav>
    </>
  );
}

export function AppLayout({ children }: { children: ReactNode }) {
  return <div className="ds-shell">{children}</div>;
}
