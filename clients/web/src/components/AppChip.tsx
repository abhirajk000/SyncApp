import type { ReactNode } from "react";

type ChipVariant = "success" | "warning" | "danger" | "primary" | "neutral";

interface Props {
  label: string;
  variant?: ChipVariant;
  icon?: ReactNode;
  className?: string;
}

export function AppChip({ label, variant = "neutral", icon, className = "" }: Props) {
  return (
    <span className={`ds-chip ds-chip--${variant} ${className}`.trim()}>
      {icon}
      {label}
    </span>
  );
}
