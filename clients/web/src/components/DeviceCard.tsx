import type { ReactNode } from "react";
import { DeviceTypeIcon } from "./DeviceTypeIcon";

type DeviceCardProps = {
  name: string;
  platform: string;
  online?: boolean;
  connectionQuality?: string;
  selected?: boolean;
  onClick?: () => void;
  trailing?: ReactNode;
};

export function DeviceCard({
  name,
  platform,
  online = true,
  connectionQuality = "Excellent",
  selected = false,
  onClick,
  trailing,
}: DeviceCardProps) {
  return (
    <button
      type="button"
      className="ds-lan-device-card"
      data-selected={selected || undefined}
      onClick={onClick}
    >
      <span className="ds-device-card__icon" aria-hidden>
        <DeviceTypeIcon platform={platform} size={20} />
      </span>
      <span className="ds-device-card__body">
        <span className="ds-device-card__title-row">
          <span
            className={`ds-device-card__dot ${online ? "ds-device-card__dot--on" : ""}`}
            aria-hidden
          />
          <span className="ds-device-card__name">{name}</span>
        </span>
        <span className="ds-device-card__meta">
          {online ? `Online · ${connectionQuality}` : "Offline"}
        </span>
      </span>
      {trailing}
    </button>
  );
}
