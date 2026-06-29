import type { ReactNode } from "react";
import { AppButton } from "./AppButton";
import { EmptyIllustration, type EmptyIllustrationVariant } from "./EmptyIllustration";

interface Props {
  icon?: ReactNode;
  illustration?: EmptyIllustrationVariant;
  title: string;
  description: string;
  actionLabel?: string;
  onAction?: () => void;
  children?: ReactNode;
}

export function AppEmptyState({
  icon,
  illustration = "inbox",
  title,
  description,
  actionLabel,
  onAction,
  children,
}: Props) {
    return (
    <div className="ds-empty sb-oneui-container sb-oneui-container--lg sb-depth-2">
      {icon ?? <EmptyIllustration variant={illustration} />}
      <h3 className="ds-empty-title">{title}</h3>
      <p className="ds-empty-desc">{description}</p>
      {actionLabel && onAction && (
        <AppButton className="sb-pressable" onClick={onAction}>
          {actionLabel}
        </AppButton>
      )}
      {children}
    </div>
  );
}
