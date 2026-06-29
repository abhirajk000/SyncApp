import type { ReactNode } from "react";
import { AppButton } from "./AppButton";
import { AppChip } from "./AppChip";
import { ItemDeleteButton } from "./ItemDeleteButton";
import { TransferBadge } from "./TransferBadge";
import { relativeTime } from "../lib/format";

export type ClipboardCardProps = {
  content: string;
  createdAt: string;
  pinned?: boolean;
  deviceName?: string;
  transferRoute?: string;
  copied?: boolean;
  inserting?: boolean;
  large?: boolean;
  isImage?: boolean;
  onCopy: () => void;
  onDelete?: () => void;
  onPin?: () => void;
  onPreview?: () => void;
  children?: ReactNode;
};

export function ClipboardCard({
  content,
  createdAt,
  pinned = false,
  deviceName,
  transferRoute,
  copied = false,
  inserting = false,
  large = false,
  isImage = false,
  onCopy,
  onDelete,
  onPin,
  onPreview,
  children,
}: ClipboardCardProps) {
  const cardClass = [
    "ds-clipboard-card",
    copied ? "ds-clipboard-card--copied" : "",
    inserting ? "ds-clipboard-card--insert" : "",
    pinned ? "ds-clipboard-card--pinned" : "",
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <article className={cardClass}>
      {(deviceName || pinned || transferRoute) && (
        <div className="ds-clipboard-card__header">
          <div className="ds-clipboard-card__badges">
            {deviceName && <AppChip label={deviceName} variant="neutral" />}
            {pinned && <AppChip label="Pinned" variant="primary" />}
            {transferRoute && (
              <TransferBadge transferMode={transferRoute} className="ds-transfer-badge--inline" />
            )}
          </div>
          <div className="ds-clipboard-card__actions">
            {onPreview && (
              <AppButton variant="ghost" size="sm" onClick={onPreview}>
                Preview
              </AppButton>
            )}
            {onPin && (
              <AppButton variant="ghost" size="sm" onClick={onPin} aria-label={pinned ? "Unpin" : "Pin"}>
                {pinned ? "Unpin" : "Pin"}
              </AppButton>
            )}
          </div>
        </div>
      )}

      <button type="button" className="ds-clipboard-card__body" onClick={onCopy}>
        {children ??
          (!isImage ? (
            <p
              className={`ds-clipboard-card__text ${large ? "ds-clipboard-card__text--large" : ""}`}
            >
              {content}
            </p>
          ) : null)}
        <div className="ds-clipboard-card__meta">
          <span>{relativeTime(createdAt)}</span>
          <span>·</span>
          <span>{isImage ? "Image" : "Text"}</span>
          <span>·</span>
          <span>Tap to copy</span>
        </div>
      </button>

      {onDelete && <ItemDeleteButton onClick={onDelete} className="ds-clipboard-card__delete" />}

      {copied && (
        <div className="ds-clipboard-card__copied" aria-live="polite">
          <span>✓ Copied</span>
        </div>
      )}
    </article>
  );
}
