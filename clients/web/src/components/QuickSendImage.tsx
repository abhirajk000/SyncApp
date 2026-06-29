import { useCallback, useRef, useState } from "react";
import { uploadFiles } from "../lib/upload";
import { AppButton } from "./AppButton";
import { AppCard } from "./AppCard";
import { IconImage } from "./Icons";
import { useToast } from "../design/ToastProvider";

export function QuickSendImage() {
  const { toast } = useToast();
  const inputRef = useRef<HTMLInputElement>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [pendingFile, setPendingFile] = useState<File | null>(null);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadFile = useCallback((file: File) => {
    if (!file.type.startsWith("image/") && !file.name.match(/\.(heic|heif)$/i)) {
      setError("Only image files are supported here");
      return;
    }
    setError(null);
    setPendingFile(file);
    setPreview(URL.createObjectURL(file));
  }, []);

  async function sendImage(file: File) {
    setSending(true);
    setError(null);
    try {
      const { failed, results } = await uploadFiles([file], () => {});
      const result = results[0];
      if (failed > 0 || result?.status === "error") {
        throw new Error(result?.error ?? "Upload failed");
      }
      window.dispatchEvent(new CustomEvent("syncbridge:files-updated"));
      toast("Image uploaded", "success");
      setPendingFile(null);
      if (preview) URL.revokeObjectURL(preview);
      setPreview(null);
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Send failed";
      setError(msg);
      toast(msg, "danger");
    } finally {
      setSending(false);
    }
  }

  async function onPaste(e: React.ClipboardEvent) {
    const items = e.clipboardData?.items;
    if (!items) return;
    for (const item of items) {
      if (!item.type.startsWith("image/")) continue;
      e.preventDefault();
      const blob = item.getAsFile();
      if (!blob) continue;
      const file = new File([blob], `paste-${Date.now()}.png`, { type: blob.type || "image/png" });
      loadFile(file);
      await sendImage(file);
      return;
    }
  }

  async function onPick(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    loadFile(file);
    await sendImage(file);
  }

  async function pasteFromClipboard() {
    setError(null);
    try {
      const items = await navigator.clipboard.read();
      for (const item of items) {
        const type = item.types.find((t) => t.startsWith("image/"));
        if (!type) continue;
        const blob = await item.getType(type);
        const file = new File([blob], `paste-${Date.now()}.png`, { type: blob.type || "image/png" });
        loadFile(file);
        await sendImage(file);
        return;
      }
      setError("No image found on your clipboard");
    } catch {
      setError("Clipboard access denied — paste with Ctrl+V instead");
    }
  }

  return (
    <AppCard onPaste={onPaste}>
      <h2 className="ds-card-title">Send Image</h2>
      <p className="ds-card-desc">
        Paste an image (Ctrl+V), pick from photos, or copy from clipboard.
      </p>

      <div className="ds-image-send-zone">
        {preview ? (
          <img src={preview} alt="Preview" className="ds-image-preview" />
        ) : (
          <div className="ds-image-send-placeholder">
            <IconImage size={28} />
            <span>Paste or choose an image</span>
          </div>
        )}
      </div>

      {error && <p className="ds-error sb-mt-3">{error}</p>}

      <div className="ds-btn-group sb-mt-3">
        <AppButton variant="secondary" size="sm" onClick={() => inputRef.current?.click()} disabled={sending}>
          Choose Image
        </AppButton>
        <AppButton variant="secondary" size="sm" onClick={() => void pasteFromClipboard()} disabled={sending}>
          Paste from Clipboard
        </AppButton>
        {pendingFile && (
          <AppButton size="sm" onClick={() => void sendImage(pendingFile)} disabled={sending}>
            {sending ? "Uploading…" : "Resend"}
          </AppButton>
        )}
      </div>

      <input ref={inputRef} type="file" accept="image/*,.heic,.heif" hidden onChange={(e) => void onPick(e)} />
    </AppCard>
  );
}
