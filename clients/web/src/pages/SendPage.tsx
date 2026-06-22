import { QuickSendFiles, QuickSendImage, QuickSendText } from "../components";

export function SendPage() {
  return (
    <div className="ds-content-narrow ds-send-page">
      <p className="ds-page-lead"></p>
      <QuickSendText />
      <QuickSendImage />
      <QuickSendFiles />
    </div>
  );
}
