import { AppButton, AppCard, AppIcon, AppSection } from "../components";
import { useTheme } from "../design/ThemeProvider";

export function SettingsPage() {
  const { theme, setTheme } = useTheme();

  return (
    <div className="ds-content-narrow">
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
          <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)", marginBottom: "var(--space-3)" }}>
            <AppIcon size="sm" alt="" />
            <strong>SyncBridge</strong>
          </div>
          <p style={{ margin: 0, fontSize: "var(--text-sm)", color: "var(--color-text-secondary)" }}>
            Instant clipboard sync across your devices.
          </p>
        </AppCard>
      </AppSection>
    </div>
  );
}
