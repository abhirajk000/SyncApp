interface Props {
  label: string;
  value: string | number;
}

export function AppStatCard({ label, value }: Props) {
  return (
    <div className="ds-card ds-stat">
      <span className="ds-stat-value">{value}</span>
      <span className="ds-stat-label">{label}</span>
    </div>
  );
}
