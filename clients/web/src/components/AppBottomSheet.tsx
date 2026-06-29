import type { ReactNode } from "react";
import { AppButton } from "./AppButton";

interface Props {
  open: boolean;
  title?: string;
  onClose: () => void;
  children: ReactNode;
}

export function AppBottomSheet({ open, title, onClose, children }: Props) {
  if (!open) return null;

  return (
    <>
      <div className="ds-bottom-sheet-backdrop" onClick={onClose} role="presentation" />
      <div className="ds-bottom-sheet" role="dialog" aria-modal="true" aria-label={title ?? "Sheet"}>
        <div className="ds-bottom-sheet__handle" aria-hidden />
        {title && (
          <div className="ds-bottom-sheet__header ds-modal-header">
            <h2 className="ds-modal-title">{title}</h2>
            <AppButton variant="ghost" size="sm" className="ds-icon-btn" onClick={onClose} aria-label="Close">
              ✕
            </AppButton>
          </div>
        )}
        {children}
      </div>
    </>
  );
}
