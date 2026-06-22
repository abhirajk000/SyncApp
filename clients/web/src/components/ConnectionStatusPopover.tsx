import { useRef, useState } from "react";
import { useNetwork } from "../design/NetworkProvider";
import { relativeTime } from "../lib/format";

interface Props {
  connected?: boolean;
}

export function ConnectionStatusPopover({ connected }: Props) {
  const net = useNetwork();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  const isConnected = connected ?? net.wsConnected;

  return (
    <div
      className="ds-conn-popover-wrap"
      ref={ref}
      onMouseEnter={() => setOpen(true)}
      onMouseLeave={() => setOpen(false)}
    >
      <button
        type="button"
        className="ds-conn-indicator"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        aria-label="Connection status"
      >
        <span className={`ds-conn-dot ${isConnected ? "ds-conn-dot--on" : "ds-conn-dot--off"}`} />
        <span className="ds-conn-label">{isConnected ? "Connected" : "Offline"}</span>
      </button>
      {open && (
        <div className="ds-conn-popover" role="tooltip">
          <p className="ds-conn-popover__title">SyncBridge Network</p>
          <dl className="ds-conn-popover__dl">
            <div><dt>Server</dt><dd>{net.diagnostics ? "Online" : "—"}</dd></div>
            <div><dt>Peers</dt><dd>{net.peers.length}</dd></div>
            <div><dt>Transfer</dt><dd>{net.currentTransferMode}</dd></div>
            <div><dt>Latency</dt><dd>{net.latencyMs != null ? `${net.latencyMs} ms` : "—"}</dd></div>
            <div><dt>Last sync</dt><dd>{net.lastSyncAt ? relativeTime(net.lastSyncAt) : "—"}</dd></div>
          </dl>
        </div>
      )}
    </div>
  );
}
