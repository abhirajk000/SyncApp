import { AppButton, AppCard, AppSection } from "../components";
import { IconDevices, IconLogout } from "../components/Icons";
import { useTheme } from "../design/ThemeProvider";
import { ChevronRight, Wifi } from "lucide-react";

interface Props {
  onLogout: () => void;
  onOpenNetwork: () => void;
  onOpenDevices: () => void;
}

export function SettingsPage({ onLogout, onOpenNetwork, onOpenDevices }: Props) {
  const { theme, setTheme } = useTheme();

  return (
    <div className="ds-content-narrow">
      <AppSection title="Devices">
        <AppCard>
          <button type="button" className="ds-settings-link" onClick={onOpenDevices}>
            <span className="ds-settings-link__icon">
              <IconDevices size={22} strokeWidth={1.75} />
            </span>
            <span className="ds-settings-link__body">
              <strong>Trusted devices</strong>
              <span className="ds-subtitle">Rename, trust, or remove devices</span>
            </span>
            <ChevronRight size={20} className="ds-settings-link__chevron" strokeWidth={2} />
          </button>
        </AppCard>
      </AppSection>

      <AppSection title="Network">
        <AppCard>
          <button type="button" className="ds-settings-link" onClick={onOpenNetwork}>
            <span className="ds-settings-link__icon">
              <Wifi size={22} strokeWidth={1.75} />
            </span>
            <span className="ds-settings-link__body">
              <strong>Network &amp; Transfer</strong>
              <span className="ds-subtitle">Status, LAN peers, transfer mode</span>
            </span>
            <ChevronRight size={20} className="ds-settings-link__chevron" strokeWidth={2} />
          </button>
        </AppCard>
      </AppSection>

      <AppSection title="Appearance">
        <AppCard>
          <p className="ds-subtitle" style={{ marginBottom: "var(--space-3)" }}>Theme</p>
          <div style={{ display: "flex", gap: "var(--space-2)", flexWrap: "wrap" }}>
            {(["system", "light", "dark"] as const).map((t) => (
              <AppButton
                key={t}
                variant={theme === t ? "primary" : "ghost"}
                size="sm"
                onClick={() => setTheme(t)}
              >
                {t.charAt(0).toUpperCase() + t.slice(1)}
              </AppButton>
            ))}
          </div>
        </AppCard>
      </AppSection>
      <AppSection title="About">
        <AppCard>
          <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)", marginBottom: "var(--space-3)" }}>
            <strong>SyncBridge</strong>
          </div>
          <p style={{ margin: 0, fontSize: "var(--text-sm)", color: "var(--color-text-secondary)" }}>
            Instant clipboard sync across your devices.
          </p>
        </AppCard>
      </AppSection>
      <AppSection title="Account">
        <AppCard>
          <AppButton variant="danger" onClick={onLogout}>
            <IconLogout size={18} />
            Log out
          </AppButton>
        </AppCard>
      </AppSection>
    </div>
  );
}
