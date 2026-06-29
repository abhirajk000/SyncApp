import type { ReactNode } from "react";

interface Props {
  title: string;
  children: ReactNode;
  action?: ReactNode;
}

export function AppSection({ title, children, action }: Props) {
  return (
    <section className="sb-oneui-section">
      <div className="sb-section__header">
        <h2 className="ds-section-title">{title}</h2>
        {action}
      </div>
      <div className="sb-oneui-container sb-oneui-container--glass">{children}</div>
    </section>
  );
}
