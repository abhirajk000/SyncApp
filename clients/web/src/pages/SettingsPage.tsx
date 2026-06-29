import { AppButton, AppSection } from "../components";
import { IconDevices, IconLogout } from "../components/Icons";
import { useTheme } from "../design/ThemeProvider";
import { ChevronRight } from "lucide-react";
import { useEffect, useState } from "react";
import { loadClipboardSettings, saveClipboardSettings } from "../lib/clipboardSettings";

interface Props {
  onLogout: () => void;
  onOpenDevices: () => void;
}

export function SettingsPage({ onLogout, onOpenDevices }: Props) {
  const { theme, setTheme } = useTheme();
  const [clipboard, setClipboard] = useState(loadClipboardSettings);

  useEffect(() => {
    const onSettings = () => setClipboard(loadClipboardSettings());
    window.addEventListener("syncbridge:clipboard-settings", onSettings);
    return () => window.removeEventListener("syncbridge:clipboard-settings", onSettings);
  }, []);

  function updateClipboard(patch: Parameters<typeof saveClipboardSettings>[0]) {
    setClipboard(saveClipboardSettings(patch));
  }

  return (
    <div className="sb-page-stack">
      <div>
        <h1 className="ds-page-title">Settings</h1>
        <p className="ds-page-lead">Devices, clipboard sync, and appearance.</p>
      </div>

      <AppSection title="Devices">
        <button type="button" className="ds-settings-link" onClick={onOpenDevices}>
          <span className="ds-settings-link__icon">
            <IconDevices size={22} strokeWidth={1.75} />
          </span>
          <span className="ds-settings-link__body">
            <strong>Devices</strong>
            <span className="ds-subtitle">Pair, rename, or remove devices</span>
          </span>
          <ChevronRight size={20} className="ds-settings-link__chevron" strokeWidth={2} />
        </button>
      </AppSection>

      <AppSection title="Clipboard">
        <label className="ds-settings-toggle">
          <span>
            <strong>Auto sync clipboard</strong>
            <span className="ds-subtitle">Upload copies from this browser tab</span>
          </span>
          <input
            type="checkbox"
            checked={clipboard.autoSyncClipboard}
            onChange={(e) => updateClipboard({ autoSyncClipboard: e.target.checked })}
          />
        </label>
        <label className="ds-settings-toggle">
          <span>
            <strong>Auto apply remote clipboard</strong>
            <span className="ds-subtitle">Try to paste synced content automatically (browser limits apply)</span>
          </span>
          <input
            type="checkbox"
            checked={clipboard.autoApplyRemoteClipboard}
            onChange={(e) => updateClipboard({ autoApplyRemoteClipboard: e.target.checked })}
          />
        </label>
        <label className="ds-settings-toggle">
          <span>
            <strong>Auto sync images</strong>
            <span className="ds-subtitle">Include photos and screenshots</span>
          </span>
          <input
            type="checkbox"
            checked={clipboard.autoSyncImages}
            onChange={(e) => updateClipboard({ autoSyncImages: e.target.checked })}
          />
        </label>
        <label className="ds-settings-toggle">
          <span>
            <strong>Show clipboard notifications</strong>
            <span className="ds-subtitle">Toast when clipboard updates from another device</span>
          </span>
          <input
            type="checkbox"
            checked={clipboard.showClipboardNotifications}
            onChange={(e) => updateClipboard({ showClipboardNotifications: e.target.checked })}
          />
        </label>
      </AppSection>

      <AppSection title="Appearance">
        <p className="ds-subtitle">Theme</p>
        <div className="sb-btn-group sb-mt-3">
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
      </AppSection>

      <AppSection title="About">
        <strong>SyncBridge</strong>
        <p className="ds-card-desc ds-card-desc--flush sb-mt-3">
          Instant clipboard sync across your devices.
        </p>
      </AppSection>

      <AppSection title="Account">
        <AppButton variant="danger" onClick={onLogout}>
          <IconLogout size={18} />
          Log out
        </AppButton>
      </AppSection>
    </div>
  );
}
