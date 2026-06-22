import { X } from "lucide-react";

interface Props {
  onClick: () => void;
  overlay?: boolean;
  className?: string;
  label?: string;
}

export function ItemDeleteButton({
  onClick,
  overlay,
  className = "",
  label = "Delete",
}: Props) {
  return (
    <button
      type="button"
      className={`ds-item-delete-btn ${overlay ? "ds-item-delete-btn--overlay" : ""} ${className}`.trim()}
      aria-label={label}
      onClick={(e) => {
        e.stopPropagation();
        e.preventDefault();
        onClick();
      }}
    >
      <X size={14} strokeWidth={2.25} />
    </button>
  );
}
