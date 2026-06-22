import type { ReactNode } from "react";
import { AppButton } from "./AppButton";

interface Props {
  open: boolean;
  title: string;
  onClose: () => void;
  children: ReactNode;
}

export function AppModal({ open, title, onClose, children }: Props) {
  if (!open) return null;
  return (
    <div className="ds-modal-backdrop" onClick={onClose} role="presentation">
      <div
        className="ds-modal"
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="ds-modal-header">
          <h2 className="ds-modal-title">{title}</h2>
          <AppButton variant="ghost" size="sm" onClick={onClose} aria-label="Close">
            ✕
          </AppButton>
        </div>
        {children}
      </div>
    </div>
  );
}
