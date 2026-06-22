import type { ReactNode } from "react";
import { AppButton } from "./AppButton";

interface Props {
  icon: ReactNode;
  title: string;
  description: string;
  actionLabel?: string;
  onAction?: () => void;
  children?: ReactNode;
}

export function AppEmptyState({ icon, title, description, actionLabel, onAction, children }: Props) {
  return (
    <div className="ds-empty">
      <div className="ds-empty-icon" aria-hidden>{icon}</div>
      <h3 className="ds-empty-title">{title}</h3>
      <p className="ds-empty-desc">{description}</p>
      {actionLabel && onAction && (
        <AppButton onClick={onAction}>{actionLabel}</AppButton>
      )}
      {children}
    </div>
  );
}
