import { useCallback, useEffect, useState } from "react";
import {
  ClipboardEntry,
  FileEntry,
  fetchClipboardHistory,
  fetchFiles,
  getAccessToken,
} from "../api";
import { AppButton, AppCard, AppSkeleton } from "../components";
import { FileRowActions } from "../components/FileRowActions";
import {
  ContentTypeIcon,
  IconFile,
  IconFolder,
  IconPin,
  IconSend,
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

  if (loading) return <AppSkeleton rows={8} />;

  return (
    <div className="ds-content-narrow ds-home">
      <section className="ds-home-section">
        <h3 className="ds-section-title">Quick actions</h3>
        <div className="ds-quick-actions">
          <button type="button" className="ds-quick-action" onClick={() => onNavigate("send")}>
            <span className="ds-quick-action-icon"><IconSend size={22} /></span>
            <span className="ds-quick-action-label">Send something</span>
            <span className="ds-quick-action-hint">Text, image, or file</span>
          </button>
          <button type="button" className="ds-quick-action" onClick={() => onNavigate("pinned")}>
            <span className="ds-quick-action-icon"><IconPin size={22} /></span>
            <span className="ds-quick-action-label">Pin important</span>
            <span className="ds-quick-action-hint">Keep forever</span>
          </button>
          <button type="button" className="ds-quick-action" onClick={() => onNavigate("files")}>
            <span className="ds-quick-action-icon"><IconFolder size={22} /></span>
            <span className="ds-quick-action-label">Browse files</span>
            <span className="ds-quick-action-hint">All transfers</span>
          </button>
        </div>
      </section>

      <div className="ds-home-columns">
        <section className="ds-home-section">
          <h3 className="ds-section-title">Recent clipboard</h3>
          {entries.length === 0 ? (
            <AppCard><p className="ds-card-desc" style={{ margin: 0 }}>No clipboard items yet.</p></AppCard>
          ) : (
            <ul className="ds-activity-list">
              {entries.map((entry) => (
                <li key={entry.id}>
                  <button type="button" className="ds-activity-item" onClick={() => void copyEntry(entry)}>
                    <span className="ds-activity-icon ds-activity-icon--clip">
                      <ContentTypeIcon contentType={entry.content_type} size={16} />
                    </span>
                    <span className="ds-activity-body">
                      {isImageContentType(entry.content_type) ? (
                        <img src={imageDataUrl(entry)} alt="" className="ds-activity-thumb" />
                      ) : (
                        <span className="ds-activity-text">{entry.content}</span>
                      )}
                      <span className="ds-activity-meta">
                        {entry.content_type} · {relativeTime(entry.created_at)}
                      </span>
                    </span>
                  </button>
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
                <li key={file.id}>
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
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </div>
  );
}
