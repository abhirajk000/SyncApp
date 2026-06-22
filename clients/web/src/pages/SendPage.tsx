import { QuickSendFiles, QuickSendImage, QuickSendText } from "../components";

export function SendPage() {
  return (
    <div className="ds-content-narrow ds-send-page">
      <p className="ds-page-lead">Send text, images, or files to your connected devices.</p>
      <QuickSendText />
      <QuickSendImage />
      <QuickSendFiles />
    </div>
  );
}
