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
  QuickSendText,
} from "../components";
import { IconClipboard, IconPin } from "../components/Icons";
import { relativeTime } from "../lib/format";

interface Props {
  pinnedOnly?: boolean;
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
              <li key={entry.id} className="ds-list-item">
                <button
                  type="button"
                  className="ds-list-body"
                  style={{ border: "none", background: "none", cursor: "pointer", padding: 0 }}
                  onClick={() => navigator.clipboard.writeText(entry.content)}
                >
                  <span className="ds-list-primary">{entry.content}</span>
                  <span className="ds-list-meta">
                    {entry.content_type} · {relativeTime(entry.created_at)}
                  </span>
                </button>
                <AppButton variant="ghost" size="sm" onClick={() => togglePin(entry)}>
                  Unpin
                </AppButton>
              </li>
            ))}
          </ul>
        </AppSection>
      </div>
    );
  }

  return (
    <div className="ds-content-narrow ds-clipboard-page">
      <QuickSendFiles />
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
              <li key={entry.id} className="ds-list-item">
                <button
                  type="button"
                  className="ds-list-body"
                  style={{ border: "none", background: "none", cursor: "pointer", padding: 0 }}
                  onClick={() => navigator.clipboard.writeText(entry.content)}
                >
                  <span className="ds-list-primary">{entry.content}</span>
                  <span className="ds-list-meta">
                    {entry.content_type} · {relativeTime(entry.created_at)}
                  </span>
                </button>
                <AppButton variant="ghost" size="sm" onClick={() => togglePin(entry)}>
                  Pin
                </AppButton>
              </li>
            ))}
          </ul>
        )}
      </AppSection>
    </div>
  );
}
