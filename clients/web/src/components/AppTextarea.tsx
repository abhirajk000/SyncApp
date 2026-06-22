import type { TextareaHTMLAttributes } from "react";

interface Props extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string;
  error?: string;
}

export function AppTextarea({ label, error, className = "", id, ...rest }: Props) {
  const inputId = id || label?.toLowerCase().replace(/\s+/g, "-");
  return (
    <div className="ds-field">
      {label && (
        <label className="ds-label" htmlFor={inputId}>
          {label}
        </label>
      )}
      <textarea
        id={inputId}
        className={`ds-textarea ${error ? "ds-input--error" : ""} ${className}`.trim()}
        {...rest}
      />
      {error && <p className="ds-error">{error}</p>}
    </div>
  );
}
