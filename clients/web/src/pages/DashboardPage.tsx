import { AppCard, AppSection, AppStatCard } from "../components";

interface Props {
  clipboardCount: number;
  pinnedCount: number;
  fileCount: number;
  connected: boolean;
}

export function DashboardPage({ clipboardCount, pinnedCount, fileCount, connected }: Props) {
  return (
    <div className="ds-content-narrow">
      <div className="ds-grid-stats" style={{ marginBottom: "var(--space-8)" }}>
        <AppStatCard label="Clipboard items" value={clipboardCount} />
        <AppStatCard label="Pinned" value={pinnedCount} />
        <AppStatCard label="Files" value={fileCount} />
        <AppStatCard label="Connection" value={connected ? "Live" : "Offline"} />
      </div>
      <AppSection title="Quick start">
        <AppCard>
          <p style={{ fontSize: "var(--text-sm)", color: "var(--color-text-secondary)", margin: 0 }}>
            Copy on any device — content appears here instantly. Pin items to keep them forever.
          </p>
        </AppCard>
      </AppSection>
    </div>
  );
}
