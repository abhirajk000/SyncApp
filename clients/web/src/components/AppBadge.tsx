type Status = "connected" | "disconnected" | "syncing" | "online" | "offline" | "success" | "warning" | "danger" | "neutral" | "primary";

interface Props {
  status: Status;
  label?: string;
}

const LABELS: Record<Status, string> = {
  connected: "Connected",
  disconnected: "Disconnected",
  syncing: "Syncing",
  online: "Online",
  offline: "Offline",
  success: "Success",
  warning: "Warning",
  danger: "Error",
  neutral: "Neutral",
  primary: "Active",
};

export function AppBadge({ status, label }: Props) {
  return (
    <span className={`ds-badge ds-badge--${status}`}>
      {label ?? LABELS[status]}
    </span>
  );
}
