import { AppIcon } from "./AppIcon";

interface Props {
  variant?: "fullscreen" | "inline";
  label?: string;
  size?: "sm" | "md" | "lg";
}

export function AppLoader({
  variant = "fullscreen",
  label = "Loading…",
  size = "lg",
}: Props) {
  if (variant === "inline") {
    return (
      <span className="ds-loader ds-loader--inline" role="status" aria-label={label}>
        <span className="ds-loader-spinner" />
      </span>
    );
  }

  return (
    <div className="ds-loader-screen" role="status" aria-live="polite" aria-label={label}>
      <div className="ds-loader-orbit">
        <div className="ds-loader-glow" aria-hidden />
        <AppIcon size={size} className="ds-loader-icon" alt="" />
        <span className="ds-loader-ring" aria-hidden />
      </div>
      <p className="ds-loader-brand">SyncBridge</p>
      <p className="ds-loader-label">{label}</p>
      <div className="ds-loader-bar" aria-hidden>
        <span className="ds-loader-bar-fill" />
      </div>
    </div>
  );
}
