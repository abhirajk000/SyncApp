import { useCallback, useEffect, useState } from "react";
import {
  ClipboardEntry,
  deleteClipboardEntry,
  fetchClipboardHistory,
  getAccessToken,
  pinClipboard,
} from "../api";
import {
  AppButton,
  AppEmptyState,
  AppSection,
  AppSkeleton,
} from "../components";
import { ClipboardImageThumb } from "../components/ClipboardImageThumb";
import { ItemDeleteButton } from "../components/ItemDeleteButton";
import { IconPin } from "../components/Icons";
import { copyEntryToClipboard, imageDataUrl, isImageContentType } from "../lib/clipboard";
import { relativeTime } from "../lib/format";
import { useToast } from "../design/ToastProvider";
import { TransferBadge } from "../components/TransferBadge";

function ClipboardHistoryItem({
  entry,
  onPin,
  onDelete,
}: {
  entry: ClipboardEntry;
  onPin: () => void;
  onDelete: () => void;
}) {
  const { toast } = useToast();
  const isImage = isImageContentType(entry.content_type);

  async function copy() {
    try {
      await copyEntryToClipboard(entry);
      toast(isImage ? "Image copied" : "Copied", "success");
    } catch {
      toast("Could not copy", "danger");
    }
  }

  return (
    <li className="ds-list-item">
      <div className="ds-list-body">
        {isImage ? (
          entry.has_thumbnail || !entry.content ? (
            <ClipboardImageThumb entryId={entry.id} className="ds-image-preview ds-image-preview--thumb" />
          ) : (
            <img src={imageDataUrl(entry)} alt="" className="ds-image-preview ds-image-preview--thumb" loading="lazy" />
          )
        ) : (
          <span className="ds-list-primary">{entry.content}</span>
        )}
        <span className="ds-list-meta">
          {entry.content_type} · {relativeTime(entry.created_at)}
        </span>
        <TransferBadge transferMode={entry.transfer_route ?? "relay"} className="ds-transfer-badge--inline" />
      </div>
      <div className="ds-list-actions">
        <AppButton variant="ghost" size="sm" onClick={() => void copy()}>
          {isImage ? "Copy Image" : "Copy"}
        </AppButton>
        <AppButton variant="ghost" size="sm" onClick={onPin}>
          Unpin
        </AppButton>
        <ItemDeleteButton onClick={onDelete} />
      </div>
    </li>
  );
}

export function PinnedPage() {
  const { toast } = useToast();
  const [entries, setEntries] = useState<ClipboardEntry[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (!getAccessToken()) return;
    setLoading(true);
    setError(null);
    try {
      const data = await fetchClipboardHistory();
      setEntries(data.entries.filter((e) => e.pinned));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    function onPin() {
      load();
    }
    function onAppRefresh() {
      load();
    }
    window.addEventListener("syncbridge:clipboard-pin", onPin);
    window.addEventListener("syncbridge:app-refresh", onAppRefresh);
    return () => {
      window.removeEventListener("syncbridge:clipboard-pin", onPin);
      window.removeEventListener("syncbridge:app-refresh", onAppRefresh);
    };
  }, [load]);

  async function unpin(entry: ClipboardEntry) {
    try {
      await pinClipboard(entry.id, false);
      setEntries((prev) => prev.filter((x) => x.id !== entry.id));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Pin failed");
    }
  }

  async function remove(entry: ClipboardEntry) {
    try {
      await deleteClipboardEntry(entry);
      setEntries((prev) => prev.filter((x) => x.id !== entry.id));
      toast("Deleted", "success");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Delete failed");
      toast("Could not delete", "danger");
    }
  }

  if (loading && entries.length === 0) {
    return <AppSkeleton rows={6} />;
  }

  if (!loading && entries.length === 0) {
    return (
      <AppEmptyState
        icon={<IconPin size={24} />}
        title="No pinned items"
        description="Pin clipboard entries to keep them synced across all devices."
      />
    );
  }

  return (
    <div className="ds-content-narrow">
      {error && <p className="ds-error" style={{ marginBottom: "var(--space-4)" }}>{error}</p>}
      <AppSection title="Pinned">
        <ul className="ds-list">
          {entries.map((entry) => (
            <ClipboardHistoryItem
              key={entry.id}
              entry={entry}
              onPin={() => unpin(entry)}
              onDelete={() => void remove(entry)}
            />
          ))}
        </ul>
      </AppSection>
    </div>
  );
}
