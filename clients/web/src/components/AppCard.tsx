import type { HTMLAttributes, ReactNode } from "react";

interface Props extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
  interactive?: boolean;
}

export function AppCard({ children, interactive, className = "", ...rest }: Props) {
  return (
    <div
      className={`ds-card ${interactive ? "ds-card--interactive" : ""} ${className}`.trim()}
      {...rest}
    >
      {children}
    </div>
  );
}
