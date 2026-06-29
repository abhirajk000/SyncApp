import type { HTMLAttributes, ReactNode } from "react";

interface Props extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
  interactive?: boolean;
  floating?: boolean;
}

export function AppCard({ children, interactive, floating, className = "", ...rest }: Props) {
  return (
    <div
      className={[
        "ds-card",
        "sb-depth-2",
        interactive ? "ds-card--interactive sb-hover-lift" : "",
        floating ? "ds-card--floating" : "",
        className,
      ]
        .filter(Boolean)
        .join(" ")}
      {...rest}
    >
      {children}
    </div>
  );
}
