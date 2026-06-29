import { AppButton } from "./AppButton";
import { AppCard } from "./AppCard";

export type TransferFileProgress = {
  name: string;
  percent: number;
};

export type TransferCardProps = {
  direction: "sending" | "receiving";
  peerName: string;
  phase: string;
  percent: number;
  speedLabel: string;
  detailLabel: string;
  files: TransferFileProgress[];
  error?: string;
  onCancel?: () => void;
  onOpenFolder?: () => void;
  onSendMore?: () => void;
  onDone?: () => void;
};

export function TransferCard({
  direction,
  peerName,
  phase,
  percent,
  speedLabel,
  detailLabel,
  files,
  error,
  onCancel,
  onOpenFolder,
  onSendMore,
  onDone,
}: TransferCardProps) {
  const title = direction === "sending" ? `Sending to ${peerName}` : `Receiving from ${peerName}`;
  return (
    <AppCard>
      <div className="ds-transfer-card__header">
        <div>
          <h3 className="ds-card-title">{title}</h3>
          <p className="ds-transfer-card__phase">{phase}</p>
        </div>
        {onCancel && (phase === "Transferring" || phase === "Paused") && (
          <AppButton variant="ghost" onClick={onCancel} aria-label="Cancel">✕</AppButton>
        )}
      </div>
      <div className="ds-progress ds-transfer-card__bar" role="progressbar" aria-valuenow={percent} aria-valuemin={0} aria-valuemax={100}>
        <div className="ds-progress__fill ds-transfer-card__bar-fill" style={{ width: `${percent}%` }} />
      </div>
      <div className="ds-transfer-card__stats">
        <span>{percent}%</span>
        <span className="ds-transfer-card__speed">{speedLabel}</span>
      </div>
      <p className="ds-transfer-card__detail">{detailLabel}</p>
      {files.map((f) => (
        <div key={f.name} className="ds-transfer-card__file">
          <span>{f.name}</span>
          <span>{Math.round(f.percent * 100)}%</span>
        </div>
      ))}
      {phase === "Completed" && (
        <div className="ds-transfer-card__done">
          <p className="ds-transfer-card__complete">Transfer Complete</p>
          <div className="ds-btn-group">
            {onOpenFolder && <AppButton variant="ghost" onClick={onOpenFolder}>Open Folder</AppButton>}
            {onSendMore && <AppButton variant="ghost" onClick={onSendMore}>Send More</AppButton>}
            {onDone && <AppButton onClick={onDone}>Done</AppButton>}
          </div>
        </div>
      )}
      {error && <p className="ds-error">{error}</p>}
    </AppCard>
  );
}
