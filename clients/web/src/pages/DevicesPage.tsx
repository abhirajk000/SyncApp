import { useCallback, useEffect, useState } from "react";
import {
  DeviceEntry,
  fetchDevices,
  renameDevice,
  revokeDevice,
} from "../api";
import { AppButton, AppCard, AppInput, AppModal, AppSection, AppSkeleton } from "../components";
import { PairQrPanel } from "../components/PairQrPanel";
import { DeviceTypeIcon } from "../components/DeviceTypeIcon";
import { ArrowLeft } from "lucide-react";
import {
  lastSeenLabel,
  onlineStatusLabel,
  platformLabel,
  setLocalDeviceName,
} from "../lib/devices";
import { useToast } from "../design/ToastProvider";

interface Props {
  onBack: () => void;
}

export function DevicesPage({ onBack }: Props) {
  const { toast } = useToast();
  const [devices, setDevices] = useState<DeviceEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [renameTarget, setRenameTarget] = useState<DeviceEntry | null>(null);
  const [renameValue, setRenameValue] = useState("");
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await fetchDevices();
      setDevices(data.devices);
    } catch {
      toast("Could not load devices", "danger");
    } finally {
      setLoading(false);
    }
  }, [toast]);

  useEffect(() => {
    void load();
  }, [load]);

  const current = devices.find((d) => d.is_current);
  const others = devices.filter((d) => !d.is_current);

  async function saveRename() {
    if (!renameTarget || !renameValue.trim()) return;
    setSaving(true);
    try {
      const updated = await renameDevice(renameTarget.id, renameValue.trim());
      if (updated.is_current) setLocalDeviceName(updated.name);
      setDevices((prev) => prev.map((d) => (d.id === updated.id ? updated : d)));
      setRenameTarget(null);
      toast("Device renamed", "success");
    } catch {
      toast("Could not rename device", "danger");
    } finally {
      setSaving(false);
    }
  }

  async function remove(device: DeviceEntry) {
    if (!window.confirm(`Remove "${device.name}" from your account?`)) return;
    try {
      await revokeDevice(device.id);
      setDevices((prev) => prev.filter((d) => d.id !== device.id));
      toast("Device removed", "success");
    } catch {
      toast("Could not remove device", "danger");
    }
  }

  if (loading) return <AppSkeleton rows={6} />;

  return (
    <div className="ds-content-narrow ds-devices-page">
      <div className="ds-devices-page__head">
        <AppButton variant="ghost" size="sm" onClick={onBack}>
          <ArrowLeft size={18} strokeWidth={2} />
          Settings
        </AppButton>
      </div>

      <h2 className="ds-title" style={{ marginBottom: "var(--space-2)" }}>Devices</h2>
      <p className="ds-subtitle" style={{ marginBottom: "var(--space-6)" }}>
        Pair new devices and manage devices on your account.
      </p>

      <AppSection title="Pair a device">
        <PairQrPanel />
      </AppSection>

      {current && (
        <AppSection title="This device">
          <DeviceCard
            device={current}
            onRename={() => {
              setRenameTarget(current);
              setRenameValue(current.name);
            }}
          />
        </AppSection>
      )}

      <AppSection title="Other devices">
        {others.length === 0 ? (
          <AppCard>
            <p className="ds-card-desc" style={{ margin: 0 }}>
              No other devices yet. Sign in on your phone, Mac, or tablet to see them here.
            </p>
          </AppCard>
        ) : (
          <div className="ds-devices-list">
            {others.map((device) => (
              <DeviceCard
                key={device.id}
                device={device}
                onRename={() => {
                  setRenameTarget(device);
                  setRenameValue(device.name);
                }}
                onRemove={() => void remove(device)}
              />
            ))}
          </div>
        )}
      </AppSection>

      <AppModal
        open={!!renameTarget}
        title="Rename device"
        onClose={() => setRenameTarget(null)}
      >
        <AppInput
          value={renameValue}
          onChange={(e) => setRenameValue(e.target.value)}
          placeholder="e.g. Abhiraj MacBook"
          autoFocus
          maxLength={64}
        />
        <div style={{ display: "flex", gap: "var(--space-2)", marginTop: "var(--space-4)" }}>
          <AppButton block onClick={() => void saveRename()} disabled={saving || !renameValue.trim()}>
            Save
          </AppButton>
          <AppButton variant="ghost" block onClick={() => setRenameTarget(null)}>
            Cancel
          </AppButton>
        </div>
      </AppModal>
    </div>
  );
}

function DeviceCard({
  device,
  onRename,
  onRemove,
}: {
  device: DeviceEntry;
  onRename: () => void;
  onRemove?: () => void;
}) {
  return (
    <AppCard className="ds-device-card">
      <div className="ds-device-card__main">
        <span className="ds-device-card__icon" aria-hidden>
          <DeviceTypeIcon platform={device.platform} size={22} />
        </span>
        <div className="ds-device-card__body">
          <div className="ds-device-card__title-row">
            <strong className="ds-device-card__name">{device.name}</strong>
            <span className={`ds-device-card__dot ${device.online ? "ds-device-card__dot--on" : ""}`} />
            <span className="ds-device-card__status">{onlineStatusLabel(device)}</span>
          </div>
          <p className="ds-device-card__meta">
            {platformLabel(device.platform)}
            {device.is_current ? " · This device" : ""}
          </p>
          <p className="ds-device-card__meta">{lastSeenLabel(device)}</p>
        </div>
      </div>
      <div className="ds-device-card__actions">
        <AppButton variant="ghost" size="sm" onClick={onRename}>
          Rename
        </AppButton>
        {onRemove && (
          <AppButton variant="danger" size="sm" onClick={onRemove}>
            Remove
          </AppButton>
        )}
      </div>
    </AppCard>
  );
}
