import { useCallback, useEffect, useState } from "react";
import QRCode from "qrcode";
import { AppButton, AppCard } from "./index";
import { initiatePairing, PairInitiateResponse } from "../api";
import { useToast } from "../design/ToastProvider";

export function PairQrPanel() {
  const { toast } = useToast();
  const [pairing, setPairing] = useState<PairInitiateResponse | null>(null);
  const [qrDataUrl, setQrDataUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const init = await initiatePairing();
      setPairing(init);
      const dataUrl = await QRCode.toDataURL(init.qr_payload, {
        width: 200,
        margin: 1,
        color: { dark: "#0f172a", light: "#ffffff" },
      });
      setQrDataUrl(dataUrl);
    } catch {
      toast("Could not start pairing", "danger");
    } finally {
      setLoading(false);
    }
  }, [toast]);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <AppCard>
      <p className="ds-card-desc ds-card-desc--flush">
        Scan this QR from SyncBridge on your phone or tablet to add it to your account.
      </p>
      <div className="ds-pair-qr">
        {loading && !qrDataUrl ? (
          <p className="ds-subtitle">Generating QR…</p>
        ) : qrDataUrl ? (
          <img src={qrDataUrl} alt="Pairing QR code" className="ds-pair-qr__image" />
        ) : null}
        {pairing?.otp && (
          <p className="ds-pair-qr__otp" aria-label="Pairing code">
            {pairing.otp}
          </p>
        )}
        <AppButton variant="ghost" size="sm" onClick={() => void load()} disabled={loading}>
          Refresh QR
        </AppButton>
      </div>
    </AppCard>
  );
}
