import { useMemo, useState } from "react";
import { Check, Monitor, Smartphone, Wifi } from "lucide-react";
import {
  AppButton,
  AppCard,
  AppEmptyState,
  DeviceCard,
  TransferCard,
} from "../components";
import { useLocalSend } from "../design/LocalSendProvider";

const STEPS = [
  "Send",
  "Nearby",
  "Device",
  "Files",
  "Preview",
  "Transfer",
  "Success",
] as const;

type MockFile = { name: string; size: number };

export function LocalSendPage({ onBack }: { onBack?: () => void }) {
  const localSend = useLocalSend();
  const [stepIndex, setStepIndex] = useState(0);
  const [selectedDevice, setSelectedDevice] = useState<string | null>(null);
  const [files, setFiles] = useState<MockFile[]>([]);
  const [transferPct, setTransferPct] = useState(0);

  const step = STEPS[stepIndex];
  const isNative = localSend.status === "native_required";

  const mockDevices = useMemo(
    () =>
      isNative
        ? []
        : [
            { id: "1", name: "MacBook Pro", platform: "macos" },
            { id: "2", name: "Pixel 8", platform: "android" },
          ],
    [isNative],
  );

  function goNext() {
    if (step === "Preview") {
      setStepIndex(STEPS.indexOf("Transfer"));
      setTransferPct(0);
      let p = 0;
      const id = window.setInterval(() => {
        p += 12;
        setTransferPct(Math.min(p, 100));
        if (p >= 100) {
          window.clearInterval(id);
          window.setTimeout(() => setStepIndex(STEPS.indexOf("Success")), 400);
        }
      }, 280);
      return;
    }
    setStepIndex((i) => Math.min(i + 1, STEPS.length - 1));
  }

  function reset() {
    setStepIndex(0);
    setSelectedDevice(null);
    setFiles([]);
    setTransferPct(0);
  }

  function pickFiles() {
    setFiles([
      { name: "Vacation.mp4", size: 48_200_000 },
      { name: "Notes.txt", size: 4_200 },
    ]);
    setStepIndex(STEPS.indexOf("Preview"));
  }

  return (
    <div className="sb-page-stack ds-local-send">
      {onBack ? (
        <div className="ds-subpage-header">
          <AppButton variant="ghost" size="sm" onClick={onBack}>
            ← Back
          </AppButton>
          <h1 className="ds-page-title">Local Send</h1>
        </div>
      ) : (
        <div>
          <h1 className="ds-page-title">Local Send</h1>
          <p className="ds-page-lead">Ultra-fast direct transfer on the same Wi‑Fi — no cloud.</p>
        </div>
      )}

      <nav className="ds-local-send__stepper" aria-label="Local Send steps">
        {STEPS.map((label, i) => (
          <div key={label} className="ds-local-send__step">
            {i > 0 && <span className="ds-local-send__step-connector" aria-hidden />}
            <span
              className={[
                "ds-local-send__step-dot",
                i < stepIndex ? "ds-local-send__step-dot--done" : "",
                i === stepIndex ? "ds-local-send__step-dot--active" : "",
              ]
                .filter(Boolean)
                .join(" ")}
            />
            <span
              className={[
                "ds-local-send__step-label",
                i === stepIndex ? "ds-local-send__step-label--active" : "",
              ]
                .filter(Boolean)
                .join(" ")}
            >
              {label}
            </span>
          </div>
        ))}
      </nav>

      <div key={step} className="ds-local-send__panel">
        {step === "Send" && (
          <AppCard floating>
            <div className="ds-hero-icon-row">
              <span className="ds-icon-hero ds-icon-hero--gradient">
                <Wifi size={22} />
              </span>
              <div>
                <h2 className="ds-card-title">Direct Wi‑Fi transfer</h2>
                <p className="ds-card-desc">
                  Send files device-to-device on the same network. No cloud upload.
                </p>
              </div>
            </div>
            <AppButton block onClick={goNext} className="sb-mt-4">
              Start
            </AppButton>
          </AppCard>
        )}

        {step === "Nearby" && (
          <>
            <div className="ds-local-send__scan">
              <span className="ds-local-send__scan-ring" />
              <span className="ds-local-send__scan-ring" />
              <Wifi size={32} className="ds-icon--primary" />
            </div>
            {isNative ? (
              <AppEmptyState
                illustration="devices"
                title="Use a native app"
                description={localSend.message}
              />
            ) : mockDevices.length === 0 ? (
              <AppEmptyState
                illustration="devices"
                title="Looking for devices…"
                description="Open Local Send on another device on the same Wi‑Fi."
              />
            ) : (
              <p className="ds-subtitle ds-subtitle--center">
                {mockDevices.length} device{mockDevices.length === 1 ? "" : "s"} nearby
              </p>
            )}
            {!isNative && mockDevices.length > 0 && (
              <AppButton block onClick={goNext}>
                Continue
              </AppButton>
            )}
          </>
        )}

        {step === "Device" && (
          <>
            {mockDevices.map((d) => (
              <DeviceCard
                key={d.id}
                name={d.name}
                platform={d.platform}
                selected={selectedDevice === d.id}
                onClick={() => setSelectedDevice(d.id)}
              />
            ))}
            <AppButton block disabled={!selectedDevice} onClick={goNext}>
              Continue
            </AppButton>
          </>
        )}

        {step === "Files" && (
          <>
            <AppCard>
              <p className="ds-card-desc">Select one or more files to send.</p>
              <AppButton block onClick={pickFiles}>
                Choose files
              </AppButton>
            </AppCard>
          </>
        )}

        {step === "Preview" && (
          <>
            <ul className="ds-local-send__preview-list">
              {files.map((f) => (
                <li key={f.name} className="ds-local-send__preview-item">
                  <span>{f.name}</span>
                  <span className="ds-list-meta">{(f.size / 1_000_000).toFixed(1)} MB</span>
                </li>
              ))}
            </ul>
            <AppButton block onClick={goNext}>
              Send now
            </AppButton>
          </>
        )}

        {step === "Transfer" && (
          <TransferCard
            direction="sending"
            peerName={mockDevices.find((d) => d.id === selectedDevice)?.name ?? "Device"}
            phase="Transferring"
            percent={transferPct}
            speedLabel="12.4 MB/s"
            detailLabel={`${transferPct}% · Direct LAN`}
            files={files.map((f) => ({ name: f.name, percent: transferPct / 100 }))}
          />
        )}

        {step === "Success" && (
          <div className="ds-local-send__success">
            <div className="ds-local-send__success-icon" aria-hidden>
              <Check size={28} strokeWidth={2.5} />
            </div>
            <h2 className="ds-card-title">Transfer complete</h2>
            <p className="ds-card-desc">Files were delivered over Wi‑Fi.</p>
            <div className="ds-btn-group ds-btn-group--center">
              <AppButton variant="ghost" onClick={reset}>
                Send more
              </AppButton>
              <AppButton onClick={onBack}>Done</AppButton>
            </div>
          </div>
        )}

        {isNative && step !== "Send" && step !== "Nearby" && (
          <AppCard>
            <h3 className="ds-card-title">Supported platforms</h3>
            <ul className="ds-platform-list">
              <li><Monitor size={16} /> macOS</li>
              <li><Smartphone size={16} /> Android</li>
              <li><Smartphone size={16} /> iPhone / iPad</li>
            </ul>
          </AppCard>
        )}
      </div>
    </div>
  );
}
