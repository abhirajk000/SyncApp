interface Props {
  size?: "sm" | "md" | "lg";
  showName?: boolean;
  className?: string;
  style?: React.CSSProperties;
}

export function AppBrand({ size = "sm", showName = true, className = "", style }: Props) {
  return (
    <div className={`ds-brand ${className}`.trim()} style={style}>
      <img
        src="/icon.png"
        alt="SyncBridge"
        className={`ds-brand-icon-img ds-brand-icon-img--${size}`}
      />
      {showName && <span className="ds-brand-name">SyncBridge</span>}
    </div>
  );
}
