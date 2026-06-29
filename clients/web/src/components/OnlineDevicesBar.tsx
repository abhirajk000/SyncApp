import { useCallback, useEffect, useState } from "react";
import { DeviceEntry, fetchDevices } from "../api";
import { DeviceTypeIcon } from "../components/DeviceTypeIcon";
import { useNetwork } from "../design/NetworkProvider";

export function OnlineDevicesBar() {
  const net = useNetwork();
  const [devices, setDevices] = useState<DeviceEntry[]>([]);

  const load = useCallback(async () => {
    try {
      const data = await fetchDevices();
      setDevices(data.devices.filter((d) => !d.is_current));
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load, net.devices]);

  const peerOnline = new Set(net.peers.map((p) => p.device_id));
  const source = devices.length ? devices : net.devices.filter((d) => !d.is_current);
  const visible = source.map((d) => ({
    ...d,
    online: d.online || peerOnline.has(d.id),
  }));

  if (visible.length === 0) return null;

  return (
    <section className="ds-trusted-devices" aria-label="Trusted devices">
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
