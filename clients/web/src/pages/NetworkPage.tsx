import { useCallback } from "react";
import { AppButton, AppCard, AppSection } from "../components";
import { ArrowLeft, RefreshCw } from "lucide-react";
import { connectedDevices, networkService } from "../lib/networkService";
import { useNetwork } from "../design/NetworkProvider";
import { relativeTime } from "../lib/format";
import { DeviceTypeIcon } from "../components/DeviceTypeIcon";
import { platformLabel } from "../lib/devices";

interface Props {
  onBack: () => void;
}

export function NetworkPage({ onBack }: Props) {
  const net = useNetwork();

  const refresh = useCallback(() => {
    void networkService.refresh();
  }, []);

  const allDevices = connectedDevices(net.devices, net.peers);
  const nearbyName = net.nearbyAlert
    ? net.devices.find((d) => d.id === net.nearbyAlert?.device_id)?.name ?? "A trusted device"
    : null;

  return (
    <div className="ds-content-narrow ds-network-page">
      <div className="ds-network-page__head">
        <AppButton variant="ghost" size="sm" onClick={onBack}>
          <ArrowLeft size={18} strokeWidth={2} />
          Settings
        </AppButton>
        <AppButton variant="ghost" size="sm" onClick={refresh} disabled={net.loading}>
          <RefreshCw size={16} className={net.loading ? "ds-spin" : ""} strokeWidth={2} />
          Refresh
        </AppButton>
      </div>

      <h2 className="ds-title" style={{ marginBottom: "var(--space-2)" }}>Network</h2>
      <p className="ds-subtitle" style={{ marginBottom: "var(--space-6)" }}>
        Sync status and connected devices on your account.
      </p>

      {nearbyName && (
        <AppCard className="ds-network-alert">
          <div className="ds-network-alert__inner">
            <div>
              <strong>{nearbyName} is nearby</strong>
              <p className="ds-subtitle" style={{ margin: "4px 0 0" }}>
                Ready to sync on the same network.
              </p>
            </div>
            <AppButton variant="ghost" size="sm" onClick={() => networkService.dismissNearbyAlert()}>
              Dismiss
            </AppButton>
          </div>
        </AppCard>
      )}

      {net.error && <p className="ds-error" style={{ marginBottom: "var(--space-4)" }}>{net.error}</p>}

      <AppSection title="Connection">
        <AppCard>
          <dl className="ds-network-dl">
            <Row label="Sync service">
              <Pill ok={!!net.diagnostics}>{net.diagnostics ? "Online" : net.loading ? "Checking…" : "Unreachable"}</Pill>
            </Row>
            <Row label="Live sync">
              <Pill ok={net.wsConnected} warn={!net.wsConnected}>
                {net.wsConnected ? "Connected" : "Disconnected"}
              </Pill>
            </Row>
            <Row label="Last sync" value={net.lastSyncAt ? relativeTime(net.lastSyncAt) : "—"} />
          </dl>
        </AppCard>
      </AppSection>

      <AppSection title="Your devices">
        <AppCard>
          {allDevices.length === 0 ? (
            <p className="ds-card-desc" style={{ margin: 0 }}>No other devices on your account yet.</p>
          ) : (
            <ul className="ds-network-peer-list">
              {allDevices.map((d) => (
                <li key={d.device_id} className="ds-network-peer">
                  <div className="ds-network-peer__left">
                    <DeviceTypeIcon platform={d.platform} size={18} />
                    <div>
                      <span className="ds-network-peer__name">{d.name}</span>
                      <span className="ds-network-meta">
                        {platformLabel(d.platform)} · {d.onLan ? "Nearby" : "Cloud"}
                      </span>
                    </div>
                  </div>
                  <span className="ds-network-meta">{relativeTime(d.updated_at)}</span>
                </li>
              ))}
            </ul>
          )}
        </AppCard>
      </AppSection>

      <AppSection title="Transfer">
        <AppCard>
          <p className="ds-card-desc" style={{ margin: 0 }}>
            Clipboard always syncs through the cloud. Files route automatically — small files via cloud,
            large transfers attempt a direct connection with cloud fallback.
          </p>
        </AppCard>
      </AppSection>
    </div>
  );
}

function Row({
  label,
  value,
  children,
}: {
  label: string;
  value?: string;
  children?: React.ReactNode;
}) {
  return (
    <div className="ds-network-dl__row">
      <dt>{label}</dt>
      <dd>{children ?? value}</dd>
    </div>
  );
}

function Pill({
  children,
  ok,
  warn,
}: {
  children: React.ReactNode;
  ok?: boolean;
  warn?: boolean;
}) {
  const cls = ok ? "ds-network-pill--ok" : warn ? "ds-network-pill--warn" : "ds-network-pill--muted";
  return <span className={`ds-network-pill ${cls}`}>{children}</span>;
}
