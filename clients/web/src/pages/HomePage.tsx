import { useCallback, useEffect, useMemo, useState } from "react";
import {
  ClipboardEntry,
  FileEntry,
  deleteClipboardEntry,
  deleteFileEntry,
  fetchClipboardHistory,
  fetchFiles,
  getAccessToken,
  pinFile,
} from "../api";
import { AppEmptyState, AppSection, AppSkeleton } from "../components";
import { OnlineDevicesBar } from "../components/OnlineDevicesBar";
import { ClipboardImageThumb } from "../components/ClipboardImageThumb";
import { FileGridCard } from "../components/FileGridCard";
import { ItemDeleteButton } from "../components/ItemDeleteButton";
import { IconText } from "../components/Icons";
import { copyEntryToClipboard, imageDataUrl, isImageContentType } from "../lib/clipboard";
import { relativeTime } from "../lib/format";
import { useToast } from "../design/ToastProvider";

const RECENT_FILES_LIMIT = 12;

function HomeTextRow({
  entry,
  onDelete,
}: {
  entry: ClipboardEntry;
  onDelete: () => void;
}) {
  const { toast } = useToast();

  async function copy() {
    try {
      await copyEntryToClipboard(entry);
      toast("Copied", "success");
    } catch {
      toast("Could not copy", "danger");
    }
  }

  return (
    <li className="ds-home-text-row">
      <button type="button" className="ds-home-text-row__body" onClick={() => void copy()}>
        <span className="ds-home-text-row__doc-icon" aria-hidden>
          <IconText size={14} />
        </span>
        <span className="ds-home-text-row__meta-wrap">
          <span className="ds-home-text-row__content">{entry.content}</span>
          <span className="ds-home-text-row__meta">{relativeTime(entry.created_at)}</span>
        </span>
      </button>
      <ItemDeleteButton onClick={onDelete} />
    </li>
  );
}

function HomeImageRow({
  entry,
  onDelete,
}: {
  entry: ClipboardEntry;
  onDelete: () => void;
}) {
  const { toast } = useToast();
  const [copying, setCopying] = useState(false);

  async function copy() {
    if (copying) return;
    setCopying(true);
    try {
      await copyEntryToClipboard(entry);
      toast("Image copied", "success");
    } catch {
      toast("Could not copy", "danger");
    } finally {
      setCopying(false);
    }
  }

  return (
    <li className="ds-home-text-row ds-home-image-row">
      <button type="button" className="ds-home-text-row__body" onClick={() => void copy()}>
        <ClipboardImageThumb entryId={entry.id} className="ds-home-image-row__thumb" />
        <span className="ds-home-text-row__meta">
          Image · {relativeTime(entry.created_at)} · Tap to copy
        </span>
      </button>
      <ItemDeleteButton onClick={onDelete} />
    </li>
  );
}

function LatestTextCard({
  entry,
  onDelete,
}: {
  entry: ClipboardEntry;
  onDelete: () => void;
}) {
  const { toast } = useToast();

  async function copy() {
    try {
      await copyEntryToClipboard(entry);
      toast("Copied", "success");
    } catch {
      toast("Could not copy", "danger");
    }
  }

  return (
    <div className="ds-home-glass-card">
      <button type="button" className="ds-home-glass-card__body" onClick={() => void copy()}>
        <p className="ds-home-glass-card__text">{entry.content}</p>
        <span className="ds-home-glass-card__meta">{relativeTime(entry.created_at)}</span>
      </button>
      <ItemDeleteButton onClick={onDelete} className="ds-home-glass-card__delete" />
    </div>
  );
}

function LatestImageCard({
  entry,
  onDelete,
}: {
  entry: ClipboardEntry;
  onDelete: () => void;
}) {
  const { toast } = useToast();
  const [copying, setCopying] = useState(false);

  async function copy() {
    if (copying) return;
    setCopying(true);
    try {
      await copyEntryToClipboard(entry);
      toast("Image copied", "success");
    } catch {
      toast("Could not copy", "danger");
    } finally {
      setCopying(false);
    }
  }

  return (
    <div className="ds-home-glass-card">
      <button
        type="button"
        className={`ds-home-glass-card__body${copying ? " ds-home-media-tap--busy" : ""}`}
        onClick={() => void copy()}
        disabled={copying}
      >
        <div className="ds-home-glass-card__image-wrap">
          {entry.has_thumbnail || !entry.content ? (
            <ClipboardImageThumb entryId={entry.id} className="ds-home-glass-card__image" />
          ) : (
            <img src={imageDataUrl(entry)} alt="" className="ds-home-glass-card__image" loading="lazy" draggable={false} />
          )}
        </div>
        <span className="ds-home-glass-card__meta">
          Tap to copy · {relativeTime(entry.created_at)}
        </span>
      </button>
      <ItemDeleteButton onClick={onDelete} className="ds-home-glass-card__delete" />
    </div>
  );
}

export function HomePage() {
  const { toast } = useToast();
  const [entries, setEntries] = useState<ClipboardEntry[]>([]);
  const [files, setFiles] = useState<FileEntry[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async (manual = false) => {
    if (!getAccessToken()) return;
    if (!manual) setLoading(true);
    try {
      const [clip, fileData] = await Promise.all([
        fetchClipboardHistory(),
        fetchFiles(),
      ]);
      setEntries(clip.entries.filter((e) => !e.pinned));
      setFiles(fileData.files.filter((f) => f.status === "ready" && !f.is_pinned));
      if (manual) toast("Synced", "success");
    } catch {
      if (manual) toast("Could not refresh", "danger");
    } finally {
      if (!manual) setLoading(false);
    }
  }, [toast]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    function onNew() {
      void load();
    }
    function onAppRefresh(e: Event) {
      const manual = (e as CustomEvent<{ manual?: boolean }>).detail?.manual ?? false;
      void load(manual);
    }
    window.addEventListener("syncbridge:clipboard-new", onNew);
    window.addEventListener("syncbridge:files-updated", onNew);
    window.addEventListener("syncbridge:app-refresh", onAppRefresh);
    return () => {
      window.removeEventListener("syncbridge:clipboard-new", onNew);
      window.removeEventListener("syncbridge:files-updated", onNew);
      window.removeEventListener("syncbridge:app-refresh", onAppRefresh);
    };
  }, [load]);

  async function removeClipboard(entry: ClipboardEntry) {
    try {
      await deleteClipboardEntry(entry);
      setEntries((prev) => prev.filter((x) => x.id !== entry.id));
      toast("Deleted", "success");
    } catch {
      toast("Could not delete", "danger");
    }
  }

  async function removeFile(file: FileEntry) {
    try {
      await deleteFileEntry(file);
      setFiles((prev) => prev.filter((x) => x.id !== file.id));
      window.dispatchEvent(new Event("syncbridge:files-updated"));
      toast("Deleted", "success");
    } catch {
      toast("Could not delete", "danger");
    }
  }

  async function togglePin(file: FileEntry) {
    try {
      await pinFile(file.id, !file.is_pinned);
      setFiles((prev) => prev.filter((f) => f.id !== file.id));
      toast("Pinned", "success");
    } catch {
      toast("Could not update pin", "danger");
    }
  }

  const unpinnedSorted = useMemo(
    () =>
      [...entries]
        .filter((e) => !e.pinned)
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()),
    [entries],
  );

  const recentFiles = useMemo(
    () =>
      [...files].sort(
        (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
      ).slice(0, RECENT_FILES_LIMIT),
    [files],
  );

  const latest = unpinnedSorted[0];
  const earlier = unpinnedSorted.slice(1);

  if (loading) return <AppSkeleton rows={8} />;

  const isEmpty = !latest && recentFiles.length === 0;

  const header = (
    <div className="ds-home-toolbar">
      <OnlineDevicesBar />
    </div>
  );

  if (isEmpty) {
    return (
      <div className="ds-content-wide ds-home">
        {header}
        <AppEmptyState
          icon={<IconText size={22} />}
          title="Nothing synced yet"
          description="Copy text or an image on any device — it appears here automatically."
        />
      </div>
    );
  }

  return (
    <div className="ds-content-wide ds-home">
      {header}

      {latest && (
        <AppSection title="Latest">
          {isImageContentType(latest.content_type) ? (
            <LatestImageCard
              entry={latest}
              onDelete={() => void removeClipboard(latest)}
            />
          ) : (
            <LatestTextCard
              entry={latest}
              onDelete={() => void removeClipboard(latest)}
            />
          )}
        </AppSection>
      )}

      {earlier.length > 0 && (
        <AppSection title="Earlier">
          <ul className="ds-home-text-list">
            {earlier.map((entry) =>
              isImageContentType(entry.content_type) ? (
                <HomeImageRow
                  key={entry.id}
                  entry={entry}
                  onDelete={() => void removeClipboard(entry)}
                />
              ) : (
                <HomeTextRow
                  key={entry.id}
                  entry={entry}
                  onDelete={() => void removeClipboard(entry)}
                />
              ),
            )}
          </ul>
        </AppSection>
      )}

      {recentFiles.length > 0 && (
        <AppSection title="Recent files">
          <div className="ds-file-grid ds-home-media-grid">
            {recentFiles.map((file) => (
              <FileGridCard
                key={file.id}
                file={file}
                onPin={togglePin}
                onDelete={removeFile}
                tapToCopy
              />
            ))}
          </div>
        </AppSection>
      )}
    </div>
  );
}
