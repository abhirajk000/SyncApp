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
import {
  AppButton,
  AppChip,
  AppEmptyState,
  AppSection,
  AppSkeleton,
  ClipboardCard,
  type NavId,
} from "../components";
import { OnlineDevicesBar } from "../components/OnlineDevicesBar";
import { ClipboardImageThumb } from "../components/ClipboardImageThumb";
import { FileGridCard } from "../components/FileGridCard";
import { copyEntryToClipboard, imageDataUrl, isImageContentType } from "../lib/clipboard";
import { formatBytes, relativeTime } from "../lib/format";
import { useToast } from "../design/ToastProvider";

const RECENT_FILES_LIMIT = 8;
const PINNED_PREVIEW_LIMIT = 5;
const ACTIVITY_LIMIT = 10;

type ActivityItem =
  | { kind: "clipboard"; id: string; at: string; entry: ClipboardEntry }
  | { kind: "file"; id: string; at: string; file: FileEntry };

export function HomePage({ onNavigate }: { onNavigate?: (id: NavId) => void }) {
  const { toast } = useToast();
  const [entries, setEntries] = useState<ClipboardEntry[]>([]);
  const [files, setFiles] = useState<FileEntry[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async (manual = false) => {
    if (!getAccessToken()) return;
    if (!manual) setLoading(true);
    try {
      const [clip, fileData] = await Promise.all([fetchClipboardHistory(), fetchFiles()]);
      setEntries(clip.entries);
      setFiles(fileData.files.filter((f) => f.status === "ready"));
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
    function mergeEntry(e: Event) {
      const entry = (e as CustomEvent<ClipboardEntry>).detail;
      if (!entry) return;
      setEntries((prev) => [entry, ...prev.filter((x) => x.id !== entry.id)]);
      setLoading(false);
    }
    function onFilesUpdated() {
      void load();
    }
    function onAppRefresh(e: Event) {
      const manual = (e as CustomEvent<{ manual?: boolean }>).detail?.manual ?? false;
      void load(manual);
    }
    window.addEventListener("syncbridge:clipboard-new", mergeEntry);
    window.addEventListener("syncbridge:files-updated", onFilesUpdated);
    window.addEventListener("syncbridge:app-refresh", onAppRefresh);
    return () => {
      window.removeEventListener("syncbridge:clipboard-new", mergeEntry);
      window.removeEventListener("syncbridge:files-updated", onFilesUpdated);
      window.removeEventListener("syncbridge:app-refresh", onAppRefresh);
    };
  }, [load]);

  const unpinnedClipboard = useMemo(
    () =>
      [...entries]
        .filter((e) => !e.pinned)
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()),
    [entries],
  );

  const pinnedClipboard = useMemo(
    () =>
      [...entries]
        .filter((e) => e.pinned)
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
        .slice(0, PINNED_PREVIEW_LIMIT),
    [entries],
  );

  const pinnedFiles = useMemo(
    () =>
      [...files]
        .filter((f) => f.is_pinned)
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
        .slice(0, 4),
    [files],
  );

  const recentFiles = useMemo(
    () =>
      [...files]
        .filter((f) => !f.is_pinned)
        .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
        .slice(0, RECENT_FILES_LIMIT),
    [files],
  );

  const activity = useMemo<ActivityItem[]>(() => {
    const items: ActivityItem[] = [
      ...entries.map((entry) => ({
        kind: "clipboard" as const,
        id: `clip-${entry.id}`,
        at: entry.created_at,
        entry,
      })),
      ...files.map((file) => ({
        kind: "file" as const,
        id: `file-${file.id}`,
        at: file.created_at,
        file,
      })),
    ];
    return items
      .sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime())
      .slice(0, ACTIVITY_LIMIT);
  }, [entries, files]);

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
      toast(file.is_pinned ? "Unpinned" : "Pinned", "success");
    } catch {
      toast("Could not update pin", "danger");
    }
  }

  async function copyEntry(entry: ClipboardEntry) {
    try {
      await copyEntryToClipboard(entry);
      toast(isImageContentType(entry.content_type) ? "Image copied" : "Copied", "success");
    } catch {
      toast("Could not copy", "danger");
    }
  }

  if (loading) return <AppSkeleton rows={8} />;

  const seeAll = (id: NavId) =>
    onNavigate ? (
      <AppButton variant="ghost" size="sm" onClick={() => onNavigate(id)}>
        See all
      </AppButton>
    ) : null;

  return (
    <div className="sb-page-stack">
      <AppSection title="Clipboard">
        {unpinnedClipboard.length === 0 ? (
          <AppEmptyState
            illustration="clipboard"
            title="No clipboard items"
            description="Copy text or an image on any device — it appears here automatically."
          />
        ) : (
          <div className="sb-stagger" style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
            {unpinnedClipboard.map((entry) =>
              isImageContentType(entry.content_type) ? (
                <ClipboardCard
                  key={entry.id}
                  content=""
                  createdAt={entry.created_at}
                  onCopy={() => void copyEntry(entry)}
                  onDelete={() => void removeClipboard(entry)}
                >
                  {entry.has_thumbnail || !entry.content ? (
                    <ClipboardImageThumb entryId={entry.id} className="ds-image-preview ds-image-preview--inline" />
                  ) : (
                    <img
                      src={imageDataUrl(entry)}
                      alt=""
                      className="ds-image-preview ds-image-preview--inline"
                      loading="lazy"
                      draggable={false}
                    />
                  )}
                </ClipboardCard>
              ) : (
                <ClipboardCard
                  key={entry.id}
                  content={entry.content}
                  createdAt={entry.created_at}
                  onCopy={() => void copyEntry(entry)}
                  onDelete={() => void removeClipboard(entry)}
                />
              ),
            )}
          </div>
        )}
      </AppSection>

      {(pinnedClipboard.length > 0 || pinnedFiles.length > 0) && (
        <AppSection title="Pinned" action={seeAll("clipboard")}>
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
            {pinnedClipboard.map((entry) => (
              <ClipboardCard
                key={entry.id}
                content={isImageContentType(entry.content_type) ? "Image" : entry.content}
                createdAt={entry.created_at}
                onCopy={() => void copyEntry(entry)}
                onDelete={() => void removeClipboard(entry)}
              />
            ))}
            {pinnedFiles.length > 0 && (
              <div className="ds-file-grid">
                {pinnedFiles.map((file) => (
                  <FileGridCard
                    key={file.id}
                    file={file}
                    onPin={togglePin}
                    onDelete={removeFile}
                  />
                ))}
              </div>
            )}
          </div>
        </AppSection>
      )}

      <AppSection title="Files" action={seeAll("files")}>
        {recentFiles.length === 0 ? (
          <AppEmptyState
            illustration="files"
            title="No files yet"
            description="Send files from another device — they appear here when ready."
          />
        ) : (
          <div className="ds-file-grid">
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
        )}
      </AppSection>

      <AppSection title="Trusted devices">
        <OnlineDevicesBar />
      </AppSection>

      {activity.length > 0 && (
        <AppSection title="Recent activity">
          <ul className="ds-list ds-home-activity-list">
            {activity.map((item) => (
              <li key={item.id} className="ds-list-item">
                <div className="ds-list-body">
                  <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)", marginBottom: "var(--space-1)" }}>
                    <AppChip
                      label={item.kind === "clipboard" ? "Clipboard" : "File"}
                      variant={item.kind === "clipboard" ? "primary" : "neutral"}
                    />
                    <span className="ds-list-meta">{relativeTime(item.at)}</span>
                  </div>
                  <span className="ds-list-primary">
                    {item.kind === "clipboard"
                      ? isImageContentType(item.entry.content_type)
                        ? "Image copied"
                        : item.entry.content.slice(0, 120)
                      : `${item.file.name} · ${formatBytes(item.file.total_size)}`}
                  </span>
                </div>
              </li>
            ))}
          </ul>
        </AppSection>
      )}
    </div>
  );
}
