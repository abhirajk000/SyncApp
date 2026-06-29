import { AppButton } from "../components";
import { ArrowLeft } from "lucide-react";
import { SendPage } from "./SendPage";

export function CloudSendPage({ onBack }: { onBack?: () => void }) {
  return (
    <div className="sb-page-stack">
      {onBack ? (
        <div className="ds-subpage-header">
          <AppButton variant="ghost" size="sm" onClick={onBack}>
            <ArrowLeft size={18} strokeWidth={2} />
            Back
          </AppButton>
          <h1 className="ds-page-title">Cloud Send</h1>
        </div>
      ) : (
        <div>
          <h1 className="ds-page-title">Cloud Send</h1>
          <p className="ds-page-lead">Send text, images, and files through the SyncBridge cloud.</p>
        </div>
      )}
      <SendPage />
    </div>
  );
}
