import { useCallback, useEffect, useState } from "react";
import {
  ClipboardEntry,
  fetchCurrentClipboard,
  getAccessToken,
} from "../api";
import { copyEntryToClipboard, imageDataUrl, isImageContentType } from "../lib/clipboard";
import { relativeTime, truncate } from "../lib/format";
import { AppButton } from "./AppButton";
import { useToast } from "../design/ToastProvider";

export function LatestClipboardCard() {
  const { toast } = useToast();
  const [latest, setLatest] = useState<ClipboardEntry | null>(null);
  const [loading, setLoading] = useState(true);
  const [copied, setCopied] = useState(false);

  const load = useCallback(async () => {
    if (!getAccessToken()) return;
    try {
      const entry = await fetchCurrentClipboard();
      setLatest(entry);
    } catch {
      setLatest(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    function onNew(e: Event) {
      const entry = (e as CustomEvent<ClipboardEntry>).detail;
      setLatest(entry);
      setCopied(false);
    }
    window.addEventListener("syncbridge:clipboard-new", onNew);
    return () => window.removeEventListener("syncbridge:clipboard-new", onNew);
  }, []);

  async function copy() {
    if (!latest) return;
    try {
      await copyEntryToClipboard(latest);
      setCopied(true);
      toast(isImageContentType(latest.content_type) ? "Image copied" : "Copied to clipboard", "success");
      setTimeout(() => setCopied(false), 2000);
    } catch {
      toast("Could not copy", "danger");
    }
  }

  if (loading) {
    return (
      <section className="ds-latest-section">
        <h2 className="ds-section-title">Latest Clipboard</h2>
        <div className="ds-latest-card ds-latest-card--loading">
          <div className="ds-skeleton ds-skeleton--title" />
          <div className="ds-skeleton ds-skeleton--text" />
          <div className="ds-skeleton ds-skeleton--text" style={{ width: "70%" }} />
        </div>
      </section>
    );
  }

  if (!latest) {
    return (
      <section className="ds-latest-section">
        <h2 className="ds-section-title">Latest Clipboard</h2>
        <div className="ds-latest-card ds-latest-card--empty">
          <p className="ds-card-desc" style={{ margin: 0 }}>
            Nothing on the clipboard yet. Send text or an image above, or copy on another device.
          </p>
        </div>
      </section>
    );
  }

  const isImage = isImageContentType(latest.content_type);

  return (
    <section className="ds-latest-section">
      <h2 className="ds-section-title">Latest Clipboard</h2>
      <div className="ds-latest-card">
        <button type="button" className="ds-latest-body" onClick={() => void copy()}>
          <span className="ds-latest-time">{relativeTime(latest.created_at)}</span>
          {isImage ? (
            <img src={imageDataUrl(latest)} alt="Clipboard" className="ds-image-preview ds-image-preview--inline" />
          ) : (
            <p className="ds-latest-content">{truncate(latest.content, 600)}</p>
          )}
        </button>
        <AppButton variant="secondary" size="sm" onClick={() => void copy()}>
          {copied ? "Copied" : isImage ? "Copy Image" : "Copy"}
        </AppButton>
      </div>
    </section>
  );
}
