import { Cloud, Wifi } from "lucide-react";

export function SendLandingPage({
  onCloud,
  onWifi,
}: {
  onCloud: () => void;
  onWifi: () => void;
}) {
  return (
    <div className="sb-page-stack">
      <div>
        <h1 className="ds-page-title">Send</h1>
        <p className="ds-page-lead">Choose how you want to transfer files.</p>
      </div>

      <div className="ds-send-landing">
        <button type="button" className="ds-send-landing__card sb-pressable" onClick={onCloud}>
          <span className="ds-send-landing__icon ds-send-landing__icon--cloud" aria-hidden>
            <Cloud size={24} />
          </span>
          <div>
            <h2 className="ds-card-title">Cloud Send</h2>
            <p className="ds-card-desc ds-card-desc--flush">
              Text, images, and files via your SyncBridge server — works on any network.
            </p>
          </div>
        </button>

        <button type="button" className="ds-send-landing__card sb-pressable" onClick={onWifi}>
          <span className="ds-send-landing__icon ds-send-landing__icon--wifi" aria-hidden>
            <Wifi size={24} />
          </span>
          <div>
            <h2 className="ds-card-title">Local Send</h2>
            <p className="ds-card-desc ds-card-desc--flush">
              Direct Wi‑Fi transfer — no cloud, no upload. Fast like AirDrop.
            </p>
          </div>
        </button>
      </div>
    </div>
  );
}
