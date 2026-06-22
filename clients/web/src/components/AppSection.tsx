import type { ReactNode } from "react";

interface Props {
  title: string;
  children: ReactNode;
  action?: ReactNode;
}

export function AppSection({ title, children, action }: Props) {
  return (
    <section style={{ marginBottom: "var(--space-6)" }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "var(--space-3)" }}>
        <h2 className="ds-section-title" style={{ margin: 0 }}>{title}</h2>
        {action}
      </div>
      {children}
    </section>
  );
}
