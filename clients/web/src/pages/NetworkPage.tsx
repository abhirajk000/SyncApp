import { useCallback } from "react";
import { AppButton, AppCard, AppSection } from "../components";
import { ArrowLeft, RefreshCw, Zap } from "lucide-react";
import { connectedDevices, networkService, platformLabel } from "../lib/networkService";
import { useNetwork } from "../design/NetworkProvider";
import { relativeTime } from "../lib/format";
import { TransferBadge } from "../components/TransferBadge";

interface Props {
  onBack: () => void;
}

export function NetworkPage({ onBack }: Props) {
  const net = useNetwork();

  const refresh = useCallback(() => {
    void networkService.refresh();
  }, []);

  const allDevices = connectedDevices(net.devices, net.peers);

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
        Live connection topology and automatic transfer routing.
      </p>

      {net.nearbyAlert && (
        <AppCard className="ds-network-alert">
          <div className="ds-network-alert__inner">
            <Zap size={22} strokeWidth={2} className="ds-network-alert__icon" />
            <div>
              <strong>Nearby device available</strong>
              <p className="ds-subtitle" style={{ margin: "4px 0 0" }}>
                Device {net.nearbyAlert.device_id.slice(0, 8)}… on {net.nearbyAlert.addrs.join(", ")}
              </p>
            </div>
            <AppButton variant="ghost" size="sm" onClick={() => networkService.dismissNearbyAlert()}>
              Dismiss
            </AppButton>
          </div>
        </AppCard>
      )}

      {net.error && <p className="ds-error" style={{ marginBottom: "var(--space-4)" }}>{net.error}</p>}

      <AppSection title="Connection status">
        <AppCard>
          <dl className="ds-network-dl">
            <Row label="Server status">
              <Pill ok={!!net.diagnostics}>{net.diagnostics ? "Online" : net.loading ? "Checking…" : "Unreachable"}</Pill>
              {net.diagnostics?.server_version && (
                <span className="ds-network-meta">v{net.diagnostics.server_version}</span>
              )}
            </Row>
            <Row label="WebSocket status">
              <Pill ok={net.wsConnected} warn={!net.wsConnected}>
                {net.wsConnected ? "Connected" : "Disconnected"}
              </Pill>
            </Row>
            <Row label="File routing" value="Automatic" />
            <Row label="Clipboard" value="Cloud relay (always)" />
            <Row label="LAN peer count" value={String(net.diagnostics?.local_peers ?? net.peers.length)} />
            <Row label="mDNS status" value={net.diagnostics?.mdns_enabled ? "Enabled" : "Disabled"} />
            <Row label="Latency" value={net.latencyMs != null ? `${net.latencyMs} ms` : "—"} />
            <Row label="Last signal" value={net.lastSignalTime ? relativeTime(net.lastSignalTime) : "Never"} />
            <Row label="Last sync" value={net.lastSyncAt ? relativeTime(net.lastSyncAt) : "—"} />
            <Row label="Your IP" value={net.diagnostics?.client_ip ?? "—"} mono />
          </dl>
        </AppCard>
      </AppSection>

      <AppSection title="Routing policy">
        <AppCard>
          <p className="ds-card-desc" style={{ margin: 0 }}>
            Clipboard text and images always sync through the cloud relay for reliability.
            Files under 100&nbsp;MB use relay. Larger files, folders, and multi-file uploads
            attempt WebRTC with automatic relay fallback. You never choose a transfer method.
          </p>
        </AppCard>
      </AppSection>

      <AppSection title="Connected devices">
        <AppCard>
          {allDevices.length === 0 ? (
            <p className="ds-card-desc" style={{ margin: 0 }}>No other devices registered yet.</p>
          ) : (
            <ul className="ds-network-peer-list">
              {allDevices.map((d) => (
                <li key={d.device_id} className="ds-network-peer">
                  <div>
                    <span className="ds-network-peer__name">
                      {d.onLan ? "✓ " : ""}{d.name}
                    </span>
                    <span className="ds-network-meta">
                      {platformLabel(d.platform)} · {d.onLan ? "Same Wi‑Fi" : "Cloud"}
                    </span>
                  </div>
                  <div className="ds-network-peer__right">
                    <TransferBadge transferMode="relay" />
                    <span className="ds-network-meta">{relativeTime(d.updated_at)}</span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </AppCard>
      </AppSection>

      <AppSection title="Nearby devices (LAN)">
        <AppCard>
          {net.enrichedPeers.length === 0 ? (
            <p className="ds-card-desc" style={{ margin: 0 }}>
              No LAN peers advertising right now. Other devices must be on the same Wi‑Fi and signed in.
            </p>
          ) : (
            <ul className="ds-network-peer-list">
              {net.enrichedPeers.map((p) => (
                <li key={p.device_id} className="ds-network-peer">
                  <div>
                    <span className="ds-network-peer__name">✓ {p.name}</span>
                    <span className="ds-network-meta">
                      {platformLabel(p.platform)} · {p.addrs.join(", ")}
                    </span>
                  </div>
                  <div className="ds-network-peer__right">
                    <TransferBadge transferMode="relay" />
                    <span className="ds-network-meta">{relativeTime(p.updated_at)}</span>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </AppCard>
      </AppSection>

      <AppSection title="Transfer diagnostics log">
        <AppCard>
          {net.transferLogs.length === 0 ? (
            <p className="ds-card-desc" style={{ margin: 0 }}>No transfers logged yet.</p>
          ) : (
            <ul className="ds-network-log-list">
              {net.transferLogs.map((log) => (
                <li key={log.id} className="ds-network-log">
                  <div className="ds-network-log__head">
                    <TransferBadge transferMode={log.method === "webrtc" ? "webrtc" : "relay"} />
                    <span className="ds-network-meta">{relativeTime(log.at)}</span>
                  </div>
                  <span className="ds-network-log__name">{log.name}</span>
                  {log.fallbackReason && (
                    <span className="ds-network-meta">Fallback: {log.fallbackReason}</span>
                  )}
                  {log.bytesPerSec != null && (
                    <span className="ds-network-meta">
                      {(log.bytesPerSec / (1024 * 1024)).toFixed(2)} MB/s
                    </span>
                  )}
                  {log.peerDeviceId && (
                    <span className="ds-network-meta">Peer: {log.peerDeviceId.slice(0, 8)}…</span>
                  )}
                </li>
              ))}
            </ul>
          )}
        </AppCard>
      </AppSection>
    </div>
  );
}

function Row({
  label,
  value,
  children,
  mono,
}: {
  label: string;
  value?: string;
  children?: React.ReactNode;
  mono?: boolean;
}) {
  return (
    <div className="ds-network-dl__row">
      <dt>{label}</dt>
      <dd className={mono ? "ds-network-mono" : undefined}>{children ?? value}</dd>
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
