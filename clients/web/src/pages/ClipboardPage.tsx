import { useCallback, useEffect, useState } from "react";
import {
  ClipboardEntry,
  fetchClipboardHistory,
  getAccessToken,
  pinClipboard,
} from "../api";
import {
  AppButton,
  AppEmptyState,
  AppSection,
  AppSkeleton,
  LatestClipboardCard,
  QuickSendFiles,
  QuickSendImage,
  QuickSendText,
} from "../components";
import { IconClipboard, IconPin } from "../components/Icons";
import { copyEntryToClipboard, imageDataUrl, isImageContentType } from "../lib/clipboard";
import { relativeTime } from "../lib/format";
import { useToast } from "../design/ToastProvider";

interface Props {
  pinnedOnly?: boolean;
}

function ClipboardHistoryItem({
  entry,
  onPin,
  pinLabel,
}: {
  entry: ClipboardEntry;
  onPin: () => void;
  pinLabel: string;
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
          <img src={imageDataUrl(entry)} alt="" className="ds-image-preview ds-image-preview--thumb" />
        ) : (
          <span className="ds-list-primary">{entry.content}</span>
        )}
        <span className="ds-list-meta">
          {entry.content_type} · {relativeTime(entry.created_at)}
        </span>
      </div>
      <div className="ds-list-actions">
        <AppButton variant="ghost" size="sm" onClick={() => void copy()}>
          {isImage ? "Copy Image" : "Copy"}
        </AppButton>
        <AppButton variant="ghost" size="sm" onClick={onPin}>
          {pinLabel}
        </AppButton>
      </div>
    </li>
  );
}

export function ClipboardPage({ pinnedOnly = false }: Props) {
  const [entries, setEntries] = useState<ClipboardEntry[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (!getAccessToken()) return;
    setLoading(true);
    setError(null);
    try {
      const data = await fetchClipboardHistory();
      setEntries(data.entries);
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
    function onNew(e: Event) {
      const entry = (e as CustomEvent<ClipboardEntry>).detail;
      setEntries((prev) => [entry, ...prev.filter((x) => x.id !== entry.id)].slice(0, 100));
    }
    function onPin(e: Event) {
      const payload = (e as CustomEvent<Record<string, unknown>>).detail;
      const id = payload.entry_id as string | undefined;
      const pinned = payload.pinned as boolean | undefined;
      if (!id) return;
      setEntries((prev) =>
        prev.map((x) => (x.id === id ? { ...x, pinned: Boolean(pinned) } : x)),
      );
    }
    window.addEventListener("syncbridge:clipboard-new", onNew);
    window.addEventListener("syncbridge:clipboard-pin", onPin);
    return () => {
      window.removeEventListener("syncbridge:clipboard-new", onNew);
      window.removeEventListener("syncbridge:clipboard-pin", onPin);
    };
  }, []);

  async function togglePin(entry: ClipboardEntry) {
    try {
      await pinClipboard(entry.id, !entry.pinned);
      setEntries((prev) =>
        prev.map((x) => (x.id === entry.id ? { ...x, pinned: !entry.pinned } : x)),
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : "Pin failed");
    }
  }

  const filtered = pinnedOnly
    ? entries.filter((e) => e.pinned)
    : entries.filter((e) => !e.pinned);

  if (pinnedOnly) {
    if (loading && entries.length === 0) {
      return <AppSkeleton rows={6} />;
    }
    if (!loading && filtered.length === 0) {
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
            {filtered.map((entry) => (
              <ClipboardHistoryItem
                key={entry.id}
                entry={entry}
                onPin={() => togglePin(entry)}
                pinLabel="Unpin"
              />
            ))}
          </ul>
        </AppSection>
      </div>
    );
  }

  return (
    <div className="ds-content-narrow ds-clipboard-page">
      <QuickSendFiles />
      <QuickSendImage />
      <QuickSendText />
      <LatestClipboardCard />

      {error && <p className="ds-error">{error}</p>}

      <AppSection title="History">
        {loading && entries.length === 0 ? (
          <AppSkeleton rows={4} />
        ) : filtered.length === 0 ? (
          <AppEmptyState
            icon={<IconClipboard size={24} />}
            title="No history yet"
            description="Items you send or copy on connected devices will appear here."
          />
        ) : (
          <ul className="ds-list">
            {filtered.map((entry) => (
              <ClipboardHistoryItem
                key={entry.id}
                entry={entry}
                onPin={() => togglePin(entry)}
                pinLabel="Pin"
              />
            ))}
          </ul>
        )}
      </AppSection>
    </div>
  );
}
