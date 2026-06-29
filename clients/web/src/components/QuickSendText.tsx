import { useState } from "react";
import { syncClipboard, type ClipboardEntry } from "../api";
import { AppButton } from "./AppButton";
import { AppCard } from "./AppCard";
import { AppTextarea } from "./AppTextarea";
import { useToast } from "../design/ToastProvider";

interface Props {
  onSent?: (entry: ClipboardEntry) => void;
}

export function QuickSendText({ onSent }: Props) {
  const { toast } = useToast();
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function send() {
    const content = text.trim();
    if (!content) return;

    setSending(true);
    setError(null);
    try {
      const entry = await syncClipboard(content);
      setText("");
      window.dispatchEvent(new CustomEvent("syncbridge:clipboard-new", { detail: entry }));
      onSent?.(entry);
      toast("Sent to clipboard", "success");
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Send failed";
      setError(msg);
      toast(msg, "danger");
    } finally {
      setSending(false);
    }
  }

  return (
    <AppCard>
      <h2 className="ds-card-title">Send Text</h2>
      <AppTextarea
        placeholder="Paste or type anything..."
        rows={5}
        value={text}
        onChange={(e) => setText(e.target.value)}
        error={error ?? undefined}
        onKeyDown={(e) => {
          if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
            e.preventDefault();
            void send();
          }
        }}
      />
      <AppButton
        block
        disabled={sending || !text.trim()}
        onClick={() => void send()}
        className="sb-mt-3"
      >
        {sending ? "Sending…" : "Send"}
      </AppButton>
    </AppCard>
  );
}
