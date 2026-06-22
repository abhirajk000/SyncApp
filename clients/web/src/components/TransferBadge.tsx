import { transferRouteFromMode, TRANSFER_BADGE } from "../lib/network";

interface Props {
  transferMode?: string;
  className?: string;
}

export function TransferBadge({ transferMode, className = "" }: Props) {
  const route = transferRouteFromMode(transferMode);
  const badge = TRANSFER_BADGE[route];
  return (
    <span className={`ds-transfer-badge ${badge.className} ${className}`.trim()} title={badge.label}>
      <span className="ds-transfer-badge__emoji" aria-hidden>
        {badge.emoji}
      </span>
      <span className="ds-transfer-badge__label">{badge.label}</span>
    </span>
  );
}
