export function AppSkeleton({ rows = 4 }: { rows?: number }) {
  return (
    <div>
      <div className="ds-skeleton ds-skeleton--title" />
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="ds-skeleton ds-skeleton--row" />
      ))}
    </div>
  );
}
