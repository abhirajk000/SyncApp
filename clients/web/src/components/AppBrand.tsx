import { AppIcon } from "./AppIcon";

interface Props {
  size?: "sm" | "md" | "lg";
  showName?: boolean;
  className?: string;
  style?: React.CSSProperties;
}

export function AppBrand({ size = "sm", showName = true, className = "", style }: Props) {
  return (
    <div className={`ds-brand ${className}`.trim()} style={style}>
      <AppIcon size={size} alt="" />
      {showName && <span className="ds-brand-name">SyncBridge</span>}
    </div>
  );
}
