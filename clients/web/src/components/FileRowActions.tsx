import { Copy, Download } from "lucide-react";
import { FileEntry } from "../api";
import { AppButton } from "./AppButton";
import { copyFileToClipboard, isImageMime } from "../lib/clipboard";
import { copyTextFile, downloadFile, isTextMime } from "../lib/files";
import { useToast } from "../design/ToastProvider";

interface Props {
  file: FileEntry;
  compact?: boolean;
}

export function FileRowActions({ file, compact }: Props) {
  const { toast } = useToast();
  const ready = file.status === "ready";

  async function onDownload() {
    try {
      await downloadFile(file.id, file.name);
      toast("Download started", "success");
    } catch {
      toast("Download failed", "danger");
    }
  }

  async function onCopy() {
    try {
      if (isImageMime(file.mime_type)) {
        await copyFileToClipboard(file.id, file.mime_type);
        toast("Image copied", "success");
      } else if (isTextMime(file.mime_type)) {
        await copyTextFile(file.id);
        toast("Copied to clipboard", "success");
      }
    } catch {
      toast("Could not copy", "danger");
    }
  }

  if (!ready) return null;

  const canCopy = isImageMime(file.mime_type) || isTextMime(file.mime_type);

  return (
    <div className="ds-list-actions">
      <AppButton variant="ghost" size="sm" onClick={() => void onDownload()}>
        {compact ? <Download size={16} strokeWidth={1.75} /> : "Download"}
      </AppButton>
      {canCopy && (
        <AppButton variant="ghost" size="sm" onClick={() => void onCopy()}>
          {compact ? <Copy size={16} strokeWidth={1.75} /> : "Copy"}
        </AppButton>
      )}
    </div>
  );
}
