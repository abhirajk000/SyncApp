import type { InputHTMLAttributes } from "react";

interface Props extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

export function AppInput({ label, error, className = "", id, ...rest }: Props) {
  const inputId = id || label?.toLowerCase().replace(/\s+/g, "-");
  return (
    <div className="ds-field">
      {label && (
        <label className="ds-label" htmlFor={inputId}>
          {label}
        </label>
      )}
      <input
        id={inputId}
        className={`ds-input ${error ? "ds-input--error" : ""} ${className}`.trim()}
        {...rest}
      />
      {error && <p className="ds-error">{error}</p>}
    </div>
  );
}
