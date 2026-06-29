interface Props {
  className?: string;
  aspectRatio?: string;
  rounded?: boolean;
}

export function ImagePlaceholder({
  className = "",
  aspectRatio = "4/3",
  rounded = true,
}: Props) {
  return (
    <span
      className={`ds-img-placeholder ${className}`.trim()}
      style={{
        display: "block",
        width: "100%",
        aspectRatio,
        borderRadius: rounded ? "var(--radius-card)" : undefined,
      }}
      aria-hidden
      role="presentation"
    />
  );
}
