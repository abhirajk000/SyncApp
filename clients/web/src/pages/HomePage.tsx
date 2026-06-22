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
import { AppEmptyState, AppSkeleton } from "../components";
import { TrustedDevicesBar } from "../components/TrustedDevicesBar";
import { ClipboardImageThumb } from "../components/ClipboardImageThumb";
import { FileGridCard } from "../components/FileGridCard";
import { ItemDeleteButton } from "../components/ItemDeleteButton";
import { IconFile, IconImage, IconText } from "../components/Icons";
import { copyEntryToClipboard, imageDataUrl, isImageContentType } from "../lib/clipboard";
import { relativeTime } from "../lib/format";
import { useToast } from "../design/ToastProvider";

type MediaItem =
  | { kind: "image"; id: string; created_at: string; entry: ClipboardEntry }
  | { kind: "file"; id: string; created_at: string; file: FileEntry };

type FeedItem =
  | { section: "text"; id: string; created_at: string; entry: ClipboardEntry }
  | { section: "media"; id: string; created_at: string; media: MediaItem };

type MobileSection =
  | { section: "text"; items: ClipboardEntry[] }
  | { section: "media"; items: MediaItem[] };

function buildMobileSections(
  textEntries: ClipboardEntry[],
  mediaItems: MediaItem[],
): MobileSection[] {
  const feed: FeedItem[] = [
    ...textEntries.map((entry) => ({
      section: "text" as const,
      id: entry.id,
      created_at: entry.created_at,
      entry,
    })),
    ...mediaItems.map((media) => ({
      section: "media" as const,
      id: media.id,
      created_at: media.created_at,
      media,
    })),
  ].sort(
    (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
  );

  const sections: MobileSection[] = [];
  for (const item of feed) {
    const last = sections[sections.length - 1];
    if (item.section === "text") {
      if (last?.section === "text") {
        last.items.push(item.entry);
      } else {
        sections.push({ section: "text", items: [item.entry] });
      }
    } else if (last?.section === "media") {
      last.items.push(item.media);
    } else {
      sections.push({ section: "media", items: [item.media] });
    }
  }
  return sections;
}

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
        <span className="ds-home-text-row__meta-wrap">
          <span className="ds-home-text-row__content">{entry.content}</span>
          <span className="ds-home-text-row__meta">{relativeTime(entry.created_at)}</span>
        </span>
      </button>
      <ItemDeleteButton onClick={onDelete} />
    </li>
  );
}

function HomeImageCard({
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
    <div className="ds-file-grid-item">
      <div className="ds-file-grid-preview-wrap">
        <button
          type="button"
          className={`ds-file-preview ds-home-media-tap${copying ? " ds-home-media-tap--busy" : ""}`}
          onClick={() => void copy()}
          disabled={copying}
          aria-label="Copy image"
        >
          {entry.has_thumbnail || !entry.content ? (
            <ClipboardImageThumb entryId={entry.id} className="ds-file-preview-image" />
          ) : (
            <img
              src={imageDataUrl(entry)}
              alt=""
              className="ds-file-preview-image"
              loading="lazy"
              draggable={false}
            />
          )}
          <span className="ds-home-media-tap__label">{copying ? "Copying…" : "Copy"}</span>
        </button>
        <ItemDeleteButton onClick={onDelete} overlay />
      </div>
      <span className="ds-file-grid-name">{relativeTime(entry.created_at)}</span>
    </div>
  );
}

function HomePaneHead({
  icon,
  title,
  count,
  accent,
}: {
  icon: React.ReactNode;
  title: string;
  count: number;
  accent: "teal" | "violet";
}) {
  return (
    <header className={`ds-home-pane__head ds-home-pane__head--${accent}`}>
      <span className="ds-home-pane__icon" aria-hidden>{icon}</span>
      <div className="ds-home-pane__titles">
        <h2 className="ds-home-pane__title">{title}</h2>
        <span className="ds-home-pane__count">{count} item{count === 1 ? "" : "s"}</span>
      </div>
    </header>
  );
}

function MediaGrid({
  items,
  onDeleteImage,
  onDeleteFile,
  onPinFile,
}: {
  items: MediaItem[];
  onDeleteImage: (entry: ClipboardEntry) => void;
  onDeleteFile: (file: FileEntry) => void;
  onPinFile: (file: FileEntry) => void;
}) {
  if (items.length === 0) {
    return (
      <AppEmptyState
        icon={<IconFile size={22} />}
        title="No photos or files"
        description="Images and transfers from your devices show up here."
      />
    );
  }

  return (
    <div className="ds-file-grid ds-home-media-grid">
      {items.map((item) =>
        item.kind === "image" ? (
          <HomeImageCard
            key={item.id}
            entry={item.entry}
            onDelete={() => onDeleteImage(item.entry)}
          />
        ) : (
          <FileGridCard
            key={item.id}
            file={item.file}
            onPin={onPinFile}
            onDelete={onDeleteFile}
            tapToCopy
          />
        ),
      )}
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
      setFiles((prev) =>
        prev.map((f) => (f.id === file.id ? { ...f, is_pinned: !f.is_pinned } : f)),
      );
      if (!file.is_pinned) {
        setFiles((prev) => prev.filter((f) => f.id !== file.id));
      }
      toast(file.is_pinned ? "Unpinned" : "Pinned", "success");
    } catch {
      toast("Could not update pin", "danger");
    }
  }

  const textEntries = useMemo(
    () =>
      entries
        .filter((e) => !isImageContentType(e.content_type))
        .sort(
          (a, b) =>
            new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
        ),
    [entries],
  );

  const mediaItems = useMemo<MediaItem[]>(() => {
    const images: MediaItem[] = entries
      .filter((e) => isImageContentType(e.content_type))
      .map((entry) => ({
        kind: "image",
        id: entry.id,
        created_at: entry.created_at,
        entry,
      }));
    const fileItems: MediaItem[] = files.map((file) => ({
      kind: "file",
      id: file.id,
      created_at: file.created_at,
      file,
    }));
    return [...images, ...fileItems].sort(
      (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
    );
  }, [entries, files]);

  const mobileSections = useMemo(
    () => buildMobileSections(textEntries, mediaItems),
    [textEntries, mediaItems],
  );

  if (loading) return <AppSkeleton rows={8} />;

  const isEmpty = textEntries.length === 0 && mediaItems.length === 0;

  if (isEmpty) {
    return (
      <div className="ds-content-wide ds-home">
        <TrustedDevicesBar />
        <AppEmptyState
          icon={<IconText size={22} />}
          title="Nothing synced yet"
          description="Copy text, an image, or send a file from any device — it will appear here."
        />
      </div>
    );
  }

  return (
    <div className="ds-content-wide ds-home">
      <TrustedDevicesBar />
      <div className="ds-home-desktop">
        <div className="ds-home-split">
          <section className="ds-home-pane ds-home-pane--text" aria-label="Text">
            <HomePaneHead
              accent="teal"
              icon={<IconText size={20} />}
              title="Text"
              count={textEntries.length}
            />
            <div className="ds-home-pane__body">
              {textEntries.length === 0 ? (
                <p className="ds-home-pane-empty">No text clips yet.</p>
              ) : (
                <ul className="ds-home-text-list">
                  {textEntries.map((entry) => (
                    <HomeTextRow
                      key={entry.id}
                      entry={entry}
                      onDelete={() => void removeClipboard(entry)}
                    />
                  ))}
                </ul>
              )}
            </div>
          </section>

          <section className="ds-home-pane ds-home-pane--media" aria-label="Photos and files">
            <HomePaneHead
              accent="violet"
              icon={<IconImage size={20} />}
              title="Photos & files"
              count={mediaItems.length}
            />
            <div className="ds-home-pane__body">
              <MediaGrid
                items={mediaItems}
                onDeleteImage={removeClipboard}
                onDeleteFile={removeFile}
                onPinFile={togglePin}
              />
            </div>
          </section>
        </div>
      </div>

      <div className="ds-home-mobile">
        {mobileSections.map((section, index) =>
          section.section === "text" ? (
            <section key={`text-${index}`} className="ds-home-mobile-block ds-home-pane ds-home-pane--text">
              <HomePaneHead
                accent="teal"
                icon={<IconText size={20} />}
                title="Text"
                count={section.items.length}
              />
              <div className="ds-home-pane__body">
                <ul className="ds-home-text-list">
                  {section.items.map((entry) => (
                    <HomeTextRow
                      key={entry.id}
                      entry={entry}
                      onDelete={() => void removeClipboard(entry)}
                    />
                  ))}
                </ul>
              </div>
            </section>
          ) : (
            <section key={`media-${index}`} className="ds-home-mobile-block ds-home-pane ds-home-pane--media">
              <HomePaneHead
                accent="violet"
                icon={<IconImage size={20} />}
                title="Photos & files"
                count={section.items.length}
              />
              <div className="ds-home-pane__body">
                <MediaGrid
                  items={section.items}
                  onDeleteImage={removeClipboard}
                  onDeleteFile={removeFile}
                  onPinFile={togglePin}
                />
              </div>
            </section>
          ),
        )}
      </div>
    </div>
  );
}
