import { useCallback, useEffect, useState } from "react";
import { DeviceEntry, fetchDevices } from "../api";
import { DeviceTypeIcon } from "../components/DeviceTypeIcon";
import { filterTrustedDevices } from "../lib/devices";
import { useNetwork } from "../design/NetworkProvider";

export function TrustedDevicesBar() {
  const net = useNetwork();
  const [devices, setDevices] = useState<DeviceEntry[]>([]);

  const load = useCallback(async () => {
    try {
      const data = await fetchDevices(true);
      setDevices(data.devices.filter((d) => !d.is_current));
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load, net.devices]);

  const trusted = filterTrustedDevices(devices.length ? devices : net.devices.filter((d) => !d.is_current));
  const peerOnline = new Set(net.peers.map((p) => p.device_id));

  const visible = trusted.map((d) => ({
    ...d,
    online: d.online || peerOnline.has(d.id),
  }));

  if (visible.length === 0) return null;

  return (
    <section className="ds-trusted-devices" aria-label="Nearby trusted devices">
      <h2 className="ds-section-title">Nearby trusted devices</h2>
      <ul className="ds-trusted-devices__list">
        {visible.map((device) => (
          <li key={device.id} className="ds-trusted-devices__item">
            <span
              className={`ds-trusted-devices__dot ${device.online ? "ds-trusted-devices__dot--on" : ""}`}
              aria-hidden
            />
            <DeviceTypeIcon platform={device.platform} size={18} className="ds-trusted-devices__type" />
            <span className="ds-trusted-devices__name">{device.name}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}
