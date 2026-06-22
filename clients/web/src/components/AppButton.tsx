import type { ButtonHTMLAttributes, ReactNode } from "react";

type Variant = "primary" | "secondary" | "ghost" | "danger";
type Size = "sm" | "md" | "lg";

interface Props extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
  block?: boolean;
  children: ReactNode;
}

export function AppButton({
  variant = "primary",
  size = "md",
  block,
  className = "",
  children,
  ...rest
}: Props) {
  const classes = [
    "ds-btn",
    `ds-btn--${variant}`,
    size !== "md" ? `ds-btn--${size}` : "",
    block ? "ds-btn--block" : "",
    className,
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <button type="button" className={classes} {...rest}>
      {children}
    </button>
  );
}
