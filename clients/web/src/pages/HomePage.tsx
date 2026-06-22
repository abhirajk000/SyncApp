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
import { TrustedDevicesBar } from "../components/TrustedDevicesBar";
import { ClipboardImageThumb } from "../components/ClipboardImageThumb";
import { FileGridCard } from "../components/FileGridCard";
import { ItemDeleteButton } from "../components/ItemDeleteButton";
import { IconImage, IconText } from "../components/Icons";
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
    if (!entry) return;
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
        <span className="ds-home-text-row__meta-wrap">
          <span className="ds-home-text-row__content">{entry.content}</span>
          <span className="ds-home-text-row__meta">{relativeTime(entry.created_at)}</span>
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
  entry?: ClipboardEntry;
  onDelete: () => void;
}) {
  const { toast } = useToast();

  if (!entry) {
    return (
      <div className="ds-latest-card ds-latest-card--text ds-latest-card--empty">
        <p>No text yet — copy on any device to sync here.</p>
      </div>
    );
  }

  const textEntry = entry;

  async function copy() {
    try {
      await copyEntryToClipboard(textEntry);
      toast("Copied", "success");
    } catch {
      toast("Could not copy", "danger");
    }
  }

  return (
    <div className="ds-latest-card ds-latest-card--text">
      <div className="ds-latest-card__head">
        <IconText size={18} />
        <span>Latest text</span>
        <ItemDeleteButton onClick={onDelete} className="ds-latest-card__delete" />
      </div>
      <button type="button" className="ds-latest-card__body" onClick={() => void copy()}>
        <p className="ds-latest-card__text">{textEntry.content}</p>
        <span className="ds-latest-card__meta">{relativeTime(textEntry.created_at)} · Tap to copy</span>
      </button>
    </div>
  );
}

function LatestImageCard({
  entry,
  onDelete,
}: {
  entry?: ClipboardEntry;
  onDelete: () => void;
}) {
  const { toast } = useToast();
  const [copying, setCopying] = useState(false);

  if (!entry) {
    return (
      <div className="ds-latest-card ds-latest-card--image ds-latest-card--empty">
        <p>No image yet — screenshots and photos sync automatically.</p>
      </div>
    );
  }

  const imageEntry = entry;

  async function copy() {
    if (copying) return;
    setCopying(true);
    try {
      await copyEntryToClipboard(imageEntry);
      toast("Image copied", "success");
    } catch {
      toast("Could not copy", "danger");
    } finally {
      setCopying(false);
    }
  }

  return (
    <div className="ds-latest-card ds-latest-card--image">
      <div className="ds-latest-card__head">
        <IconImage size={18} />
        <span>Latest image</span>
        <ItemDeleteButton onClick={onDelete} className="ds-latest-card__delete" />
      </div>
      <button
        type="button"
        className={`ds-latest-card__body ds-latest-card__body--image${copying ? " ds-home-media-tap--busy" : ""}`}
        onClick={() => void copy()}
        disabled={copying}
      >
        <div className="ds-latest-card__image-wrap">
          {imageEntry.has_thumbnail || !imageEntry.content ? (
            <ClipboardImageThumb entryId={imageEntry.id} className="ds-latest-card__image" />
          ) : (
            <img src={imageDataUrl(imageEntry)} alt="" className="ds-latest-card__image" loading="lazy" draggable={false} />
          )}
        </div>
        <span className="ds-latest-card__meta">{relativeTime(imageEntry.created_at)} · Tap to copy</span>
      </button>
    </div>
  );
}

export function HomePage() {
  const { toast } = useToast();
  const [entries, setEntries] = useState<ClipboardEntry[]>([]);
  const [files, setFiles] = useState<FileEntry[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (!getAccessToken()) return;
    setLoading(true);
    try {
      const [clip, fileData] = await Promise.all([
        fetchClipboardHistory(),
        fetchFiles(),
      ]);
      setEntries(clip.entries.filter((e) => !e.pinned));
      setFiles(fileData.files.filter((f) => f.status === "ready" && !f.is_pinned));
    } catch {
      /* ignore */
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    function onNew() {
      load();
    }
    window.addEventListener("syncbridge:clipboard-new", onNew);
    window.addEventListener("syncbridge:files-updated", onNew);
    return () => {
      window.removeEventListener("syncbridge:clipboard-new", onNew);
      window.removeEventListener("syncbridge:files-updated", onNew);
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

  const textEntries = useMemo(
    () =>
      entries
        .filter((e) => !isImageContentType(e.content_type))
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()),
    [entries],
  );

  const imageEntries = useMemo(
    () =>
      entries
        .filter((e) => isImageContentType(e.content_type))
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

  const latestText = textEntries[0];
  const latestImage = imageEntries[0];
  const olderText = textEntries.slice(1);

  if (loading) return <AppSkeleton rows={8} />;

  const isEmpty = !latestText && !latestImage && recentFiles.length === 0;

  if (isEmpty) {
    return (
      <div className="ds-content-wide ds-home">
        <TrustedDevicesBar />
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
      <TrustedDevicesBar />

      <div className="ds-home-latest-grid">
        <LatestTextCard
          entry={latestText}
          onDelete={() => latestText && void removeClipboard(latestText)}
        />
        <LatestImageCard
          entry={latestImage}
          onDelete={() => latestImage && void removeClipboard(latestImage)}
        />
      </div>

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

      {olderText.length > 0 && (
        <AppSection title="Earlier text">
          <ul className="ds-home-text-list">
            {olderText.map((entry) => (
              <HomeTextRow
                key={entry.id}
                entry={entry}
                onDelete={() => void removeClipboard(entry)}
              />
            ))}
          </ul>
        </AppSection>
      )}
    </div>
  );
}
