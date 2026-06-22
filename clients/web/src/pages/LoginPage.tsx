import { useState } from "react";
import { unlock } from "../api";
import { AppButton, AppCard, AppIcon, AppInput, AppLoader } from "../components";

interface Props {
  onSuccess: () => void | Promise<void>;
}

export function LoginPage({ onSuccess }: Props) {
  const [pin, setPin] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function submit() {
    if (loading || !pin) return;
    setError(null);
    setLoading(true);
    try {
      await unlock(pin);
      setPin("");
      await onSuccess();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unlock failed");
    } finally {
      setLoading(false);
    }
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    void submit();
  }

  return (
    <div className="ds-login-wrap ds-app">
      <AppCard className="ds-login-card">
        <div className="ds-login-hero">
          <AppIcon size="lg" className="ds-login-hero-icon" alt="" />
          <h1 className="ds-login-title">SyncBridge</h1>
          <p className="ds-login-subtitle">Enter your PIN to unlock</p>
        </div>

        <form className="ds-login-form" onSubmit={handleSubmit}>
          <AppInput
            type="password"
            value={pin}
            onChange={(e) => setPin(e.target.value)}
            inputMode="numeric"
            autoComplete="off"
            autoFocus
            aria-label="PIN"
            error={error ?? undefined}
            className="ds-login-pin"
          />
          <AppButton type="submit" block size="lg" disabled={loading || !pin}>
            {loading ? (
              <span className="ds-btn-busy">
                <AppLoader variant="inline" label="Unlocking" />
                Unlocking…
              </span>
            ) : (
              "Unlock"
            )}
          </AppButton>
        </form>
      </AppCard>
    </div>
  );
}
