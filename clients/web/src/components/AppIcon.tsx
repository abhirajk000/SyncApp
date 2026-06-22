interface Props {
  size?: "sm" | "md" | "lg";
  className?: string;
  alt?: string;
}

export function AppIcon({ size = "md", className = "", alt = "SyncBridge" }: Props) {
  return (
    <div className={`ds-app-icon ds-app-icon--${size} ${className}`.trim()}>
      <img src="/icon.png" alt={alt} />
    </div>
  );
}
