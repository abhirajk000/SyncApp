import { useEffect, useState } from "react";
import { useNetwork } from "../design/NetworkProvider";
import { fetchDevices } from "../api";
import { filterTrustedDevices } from "../lib/devices";

interface Props {
  connected?: boolean;
}

export function ConnectionStatusPopover({ connected }: Props) {
  const net = useNetwork();
  const [open, setOpen] = useState(false);
  const [trustedNames, setTrustedNames] = useState<string[]>([]);

  const isConnected = connected ?? net.wsConnected;

  useEffect(() => {
    if (!open) return;
    void fetchDevices(true).then((data) => {
      const names = filterTrustedDevices(data.devices)
        .filter((d) => !d.is_current && (d.online || net.peers.some((p) => p.device_id === d.id)))
        .map((d) => d.name);
      setTrustedNames(names);
    }).catch(() => setTrustedNames([]));
  }, [open, net.peers]);

  return (
    <div
      className="ds-conn-popover-wrap"
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
          <p className="ds-conn-popover__title">Sync status</p>
          <dl className="ds-conn-popover__dl">
            <div><dt>Service</dt><dd>{net.diagnostics ? "Online" : "—"}</dd></div>
            <div><dt>Live sync</dt><dd>{isConnected ? "Connected" : "Offline"}</dd></div>
          </dl>
          {trustedNames.length > 0 && (
            <div className="ds-conn-popover__devices">
              <p className="ds-conn-popover__subtitle">Online devices</p>
              <ul className="ds-trusted-devices__list ds-trusted-devices__list--compact">
                {trustedNames.map((name) => (
                  <li key={name} className="ds-trusted-devices__item">
                    <span className="ds-trusted-devices__dot ds-trusted-devices__dot--on" aria-hidden />
                    <span className="ds-trusted-devices__name">{name}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
