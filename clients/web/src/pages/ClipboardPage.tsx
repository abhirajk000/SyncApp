import { useCallback, useEffect, useState } from "react";
import {
  ClipboardEntry,
  deleteClipboardEntry,
  fetchClipboardHistory,
  getAccessToken,
  pinClipboard,
} from "../api";
import {
  AppEmptyState,
  AppSection,
  AppSkeleton,
  ClipboardCard,
} from "../components";
import { ClipboardImageThumb } from "../components/ClipboardImageThumb";
import { copyEntryToClipboard, imageDataUrl, isImageContentType } from "../lib/clipboard";
import { useToast } from "../design/ToastProvider";

export function PinnedPage({ embedded = false }: { embedded?: boolean }) {
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
    function onPin(e: Event) {
      const detail = (e as CustomEvent<{ entry_id?: string; pinned?: boolean }>).detail;
      const entryId = detail?.entry_id;
      const pinned = detail?.pinned;
      if (!entryId || pinned === undefined) {
        load();
        return;
      }
      setEntries((prev) => {
        if (pinned) {
          if (prev.some((x) => x.id === entryId)) {
            return prev.map((x) => (x.id === entryId ? { ...x, pinned: true } : x));
          }
          return prev;
        }
        return prev.filter((x) => x.id !== entryId);
      });
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

  async function copyEntry(entry: ClipboardEntry) {
    try {
      await copyEntryToClipboard(entry);
      toast(isImageContentType(entry.content_type) ? "Image copied" : "Copied", "success");
    } catch {
      toast("Could not copy", "danger");
    }
  }

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

  const pageHeader = !embedded && (
    <div>
      <h1 className="ds-page-title">Pinned</h1>
      <p className="ds-page-lead">Items you keep forever — synced across all devices.</p>
    </div>
  );

  if (loading && entries.length === 0) {
    return embedded ? (
      <AppSkeleton rows={6} />
    ) : (
      <div className="sb-page-stack">
        {pageHeader}
        <AppSkeleton rows={6} />
      </div>
    );
  }

  if (!loading && entries.length === 0) {
    const empty = (
      <AppEmptyState
        illustration="pinned"
        title="No pinned items"
        description="Pin clipboard entries to keep them synced across all devices."
      />
    );
    return embedded ? empty : (
      <div className="sb-page-stack">
        {pageHeader}
        {empty}
      </div>
    );
  }

  const list = (
    <ul className="sb-oneui-group">
      {entries.map((entry) => {
        const isImage = isImageContentType(entry.content_type);
        return (
          <li key={entry.id} className="sb-oneui-group__item sb-oneui-group__item--clipboard">
            <div className="sb-oneui-group__body">
              <ClipboardCard
                content={isImage ? "" : entry.content}
                createdAt={entry.created_at}
                pinned
                transferRoute={entry.transfer_route ?? "relay"}
                isImage={isImage}
                onCopy={() => void copyEntry(entry)}
                onDelete={() => void remove(entry)}
                onPin={() => void unpin(entry)}
              >
                {isImage &&
                  (entry.has_thumbnail || !entry.content ? (
                    <ClipboardImageThumb
                      entryId={entry.id}
                      className="ds-clipboard-card__image ds-image-preview"
                    />
                  ) : (
                    <img
                      src={imageDataUrl(entry)}
                      alt=""
                      className="ds-clipboard-card__image"
                      loading="lazy"
                      draggable={false}
                    />
                  ))}
              </ClipboardCard>
            </div>
          </li>
        );
      })}
    </ul>
  );

  if (embedded) {
    return (
      <>
        {error && <p className="ds-error ds-error--spaced">{error}</p>}
        {list}
      </>
    );
  }

  return (
    <div className="sb-page-stack">
      {pageHeader}
      {error && <p className="ds-error ds-error--spaced">{error}</p>}
      <AppSection title="Pinned">{list}</AppSection>
    </div>
  );
}
