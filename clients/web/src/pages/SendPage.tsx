import { QuickSendFiles, QuickSendImage, QuickSendText } from "../components";

export function SendPage() {
  return (
    <div className="sb-stack-3">
      <QuickSendText />
      <QuickSendImage />
      <QuickSendFiles />
    </div>
  );
}
