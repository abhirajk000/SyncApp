import { useCallback, useEffect, useState } from "react";
import {
  ClipboardEntry,
  FileEntry,
  deleteClipboardEntry,
  deleteFileEntry,
  fetchClipboardHistory,
  fetchFiles,
  getAccessToken,
} from "../api";
import { AppButton, AppCard, AppSkeleton } from "../components";
import { ClipboardImageThumb } from "../components/ClipboardImageThumb";
import { FileRowActions } from "../components/FileRowActions";
import { ItemDeleteButton } from "../components/ItemDeleteButton";
import {
  ContentTypeIcon,
  IconFile,
} from "../components/Icons";
import { copyEntryToClipboard, imageDataUrl, isImageContentType } from "../lib/clipboard";
import { formatBytes, relativeTime } from "../lib/format";
import { useToast } from "../design/ToastProvider";
import type { NavId } from "../components/AppBottomNav";

interface Props {
  onNavigate: (id: NavId) => void;
}

export function HomePage({ onNavigate }: Props) {
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
      setEntries(clip.entries.slice(0, 6));
      setFiles(fileData.files.filter((f) => f.status === "ready").slice(0, 5));
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

  async function copyEntry(entry: ClipboardEntry) {
    try {
      await copyEntryToClipboard(entry);
      toast("Copied", "success");
    } catch {
      toast("Could not copy", "danger");
    }
  }

  async function removeClipboard(entry: ClipboardEntry) {
    try {
      await deleteClipboardEntry(entry);
      setEntries((prev) => prev.filter((e) => e.id !== entry.id));
      toast("Deleted", "success");
    } catch {
      toast("Could not delete", "danger");
    }
  }

  async function removeFile(file: FileEntry) {
    try {
      await deleteFileEntry(file);
      setFiles((prev) => prev.filter((f) => f.id !== file.id));
      window.dispatchEvent(new CustomEvent("syncbridge:files-updated"));
      toast("Deleted", "success");
    } catch {
      toast("Could not delete", "danger");
    }
  }

  if (loading) return <AppSkeleton rows={8} />;

  return (
    <div className="ds-content-narrow ds-home">
      <div className="ds-home-columns">
        <section className="ds-home-section">
          <h3 className="ds-section-title">Recent clipboard</h3>
          {entries.length === 0 ? (
            <AppCard><p className="ds-card-desc" style={{ margin: 0 }}>No clipboard items yet.</p></AppCard>
          ) : (
            <ul className="ds-activity-list">
              {entries.map((entry) => (
                <li key={entry.id} className="ds-activity-row">
                  <button type="button" className="ds-activity-item" onClick={() => void copyEntry(entry)}>
                    <span className="ds-activity-icon ds-activity-icon--clip">
                      <ContentTypeIcon contentType={entry.content_type} size={16} />
                    </span>
                    <span className="ds-activity-body">
                      {isImageContentType(entry.content_type) ? (
                        entry.has_thumbnail || !entry.content ? (
                          <ClipboardImageThumb entryId={entry.id} />
                        ) : (
                          <img src={imageDataUrl(entry)} alt="" className="ds-activity-thumb" loading="lazy" />
                        )
                      ) : (
                        <span className="ds-activity-text">{entry.content}</span>
                      )}
                      <span className="ds-activity-meta">
                        {entry.content_type} · {relativeTime(entry.created_at)}
                      </span>
                    </span>
                  </button>
                  <ItemDeleteButton onClick={() => void removeClipboard(entry)} />
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="ds-home-section">
          <div className="ds-home-section-head">
            <h3 className="ds-section-title">Recent files</h3>
            <AppButton variant="ghost" size="sm" onClick={() => onNavigate("files")}>
              See all
            </AppButton>
          </div>
          {files.length === 0 ? (
            <AppCard><p className="ds-card-desc" style={{ margin: 0 }}>No files yet.</p></AppCard>
          ) : (
            <ul className="ds-activity-list">
              {files.map((file) => (
                <li key={file.id} className="ds-activity-row">
                  <div className="ds-activity-item ds-activity-item--static ds-activity-item--with-actions">
                    <span className="ds-activity-icon ds-activity-icon--file">
                      <IconFile size={16} />
                    </span>
                    <span className="ds-activity-body">
                      <span className="ds-activity-text">{file.name}</span>
                      <span className="ds-activity-meta">
                        {formatBytes(file.total_size)} · {relativeTime(file.created_at)}
                      </span>
                    </span>
                    <FileRowActions file={file} compact />
                  </div>
                  <ItemDeleteButton onClick={() => void removeFile(file)} />
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </div>
  );
}
