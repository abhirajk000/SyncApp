import { useState } from "react";
import { getServerUrl, setServerUrl } from "../api";
import { AppButton, AppCard, AppInput, AppSection } from "../components";
import { useTheme } from "../design/ThemeProvider";

export function SettingsPage() {
  const { theme, setTheme } = useTheme();
  const [serverUrl, setServerUrlInput] = useState(getServerUrl());

  return (
    <div className="ds-content-narrow">
      <AppSection title="Server">
        <AppCard>
          <AppInput
            label="API URL"
            type="url"
            value={serverUrl}
            onChange={(e) => setServerUrlInput(e.target.value)}
          />
          <AppButton
            style={{ marginTop: "var(--space-3)" }}
            onClick={() => setServerUrl(serverUrl)}
          >
            Save
          </AppButton>
        </AppCard>
      </AppSection>
      <AppSection title="Appearance">
        <AppCard>
          <p className="ds-subtitle" style={{ marginBottom: "var(--space-3)" }}>Theme</p>
          <div style={{ display: "flex", gap: "var(--space-2)" }}>
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
          <p style={{ margin: 0, fontSize: "var(--text-sm)", color: "var(--color-text-secondary)" }}>
            SyncBridge — instant clipboard sync across your devices.
          </p>
        </AppCard>
      </AppSection>
    </div>
  );
}
