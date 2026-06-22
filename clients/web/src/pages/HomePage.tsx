import { useCallback, useEffect, useState, type ReactNode } from "react";
import {
  ClipboardEntry,
  FileEntry,
  deleteClipboardEntry,
  deleteFileEntry,
  fetchClipboardHistory,
  fetchFiles,
  getAccessToken,
} from "../api";
import { AppSkeleton } from "../components";
import { ClipboardImageThumb } from "../components/ClipboardImageThumb";
import { FileRowActions } from "../components/FileRowActions";
import { ItemDeleteButton } from "../components/ItemDeleteButton";
import { IconFile, IconImage, IconPin, IconSend, IconSpark, IconText } from "../components/Icons";
import { copyEntryToClipboard, imageDataUrl, isImageContentType } from "../lib/clipboard";
import { formatBytes, relativeTime } from "../lib/format";
import { useToast } from "../design/ToastProvider";
import { TransferBadge } from "../components/TransferBadge";
import type { NavId } from "../components/AppBottomNav";
import { ChevronRight } from "lucide-react";

interface Props {
  onNavigate: (id: NavId) => void;
}

function latestText(entries: ClipboardEntry[]) {
  return entries.find((e) => !isImageContentType(e.content_type));
}

function latestImage(entries: ClipboardEntry[]) {
  return entries.find((e) => isImageContentType(e.content_type));
}

type TileAccent = "teal" | "violet" | "blue";

function DashTile({
  accent,
  icon,
  label,
  empty,
  time,
  onClick,
  onDelete,
  children,
  foot,
}: {
  accent: TileAccent;
  icon: ReactNode;
  label: string;
  empty?: string;
  time?: string;
  onClick?: () => void;
  onDelete?: () => void;
  children?: ReactNode;
  foot?: ReactNode;
}) {
  return (
    <div
      className={`ds-dash-tile ds-dash-tile--${accent}${onClick ? " ds-dash-tile--clickable" : ""}`}
      onClick={onClick}
      onKeyDown={
        onClick
          ? (e) => {
              if (e.key === "Enter" || e.key === " ") {
                e.preventDefault();
                onClick();
              }
            }
          : undefined
      }
      role={onClick ? "button" : undefined}
      tabIndex={onClick ? 0 : undefined}
    >
      <div className="ds-dash-tile__head">
        <span className="ds-dash-tile__icon">{icon}</span>
        <span className="ds-dash-tile__label">{label}</span>
        {onDelete && <ItemDeleteButton onClick={onDelete} className="ds-dash-tile__delete" />}
      </div>
      <div className="ds-dash-tile__body">
        {empty ? <p className="ds-dash-tile__empty">{empty}</p> : children}
      </div>
      <div className="ds-dash-tile__foot">
        {time && <span className="ds-dash-tile__time">{time}</span>}
        {foot}
        {onClick && !empty && (
          <span className="ds-dash-tile__action">
            Tap to copy
            <ChevronRight size={14} strokeWidth={2.5} />
          </span>
        )}
      </div>
    </div>
  );
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
      setEntries(clip.entries);
      setFiles(fileData.files.filter((f) => f.status === "ready"));
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
      toast(isImageContentType(entry.content_type) ? "Image copied" : "Copied", "success");
    } catch {
      toast("Could not copy", "danger");
    }
  }

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

  if (loading) return <AppSkeleton rows={8} />;

  const textEntry = latestText(entries);
  const imageEntry = latestImage(entries);
  const latestFile = files.find((f) => !f.is_pinned);
  const textCount = entries.filter((e) => !isImageContentType(e.content_type)).length;
  const imageCount = entries.filter((e) => isImageContentType(e.content_type)).length;
  const fileCount = files.length;

  return (
    <div className="ds-content-narrow ds-home">
      <header className="ds-dash-hero">
        <div className="ds-dash-hero__badge" aria-hidden>
          <IconSpark size={22} />
        </div>
        <div className="ds-dash-hero__text">
          <h1 className="ds-dash-hero__title">Your sync hub</h1>
          <p className="ds-dash-hero__sub">
            Latest text, images, and files from every device — updated live.
          </p>
        </div>
      </header>

      <div className="ds-overview-stats ds-dash-stats">
        <div className="ds-overview-stat ds-overview-stat--green">
          <span className="ds-overview-stat-icon">
            <IconText size={20} />
          </span>
          <span className="ds-overview-stat-body">
            <span className="ds-overview-stat-value">{textCount}</span>
            <span className="ds-overview-stat-label">Text clips</span>
          </span>
        </div>
        <div className="ds-overview-stat ds-overview-stat--purple">
          <span className="ds-overview-stat-icon">
            <IconImage size={20} />
          </span>
          <span className="ds-overview-stat-body">
            <span className="ds-overview-stat-value">{imageCount}</span>
            <span className="ds-overview-stat-label">Images</span>
          </span>
        </div>
        <div className="ds-overview-stat ds-overview-stat--blue">
          <span className="ds-overview-stat-icon">
            <IconFile size={20} />
          </span>
          <span className="ds-overview-stat-body">
            <span className="ds-overview-stat-value">{fileCount}</span>
            <span className="ds-overview-stat-label">Files</span>
          </span>
        </div>
      </div>

      <div className="ds-dash-grid">
        <DashTile
          accent="teal"
          icon={<IconText size={18} />}
          label="Latest text"
          empty={textEntry ? undefined : "Copy on any device — it appears here."}
          time={textEntry ? relativeTime(textEntry.created_at) : undefined}
          onClick={textEntry ? () => void copyEntry(textEntry) : undefined}
          onDelete={textEntry ? () => void removeClipboard(textEntry) : undefined}
        >
          {textEntry && (
            <p className="ds-dash-tile__preview ds-dash-tile__preview--text">
              {textEntry.content}
            </p>
          )}
        </DashTile>

        <DashTile
          accent="violet"
          icon={<IconImage size={18} />}
          label="Latest image"
          empty={imageEntry ? undefined : "Screenshots and photos sync automatically."}
          time={imageEntry ? relativeTime(imageEntry.created_at) : undefined}
          onClick={imageEntry ? () => void copyEntry(imageEntry) : undefined}
          onDelete={imageEntry ? () => void removeClipboard(imageEntry) : undefined}
        >
          {imageEntry && (
            <div className="ds-dash-tile__image-wrap">
              {imageEntry.has_thumbnail || !imageEntry.content ? (
                <ClipboardImageThumb entryId={imageEntry.id} className="ds-dash-tile__image" />
              ) : (
                <img
                  src={imageDataUrl(imageEntry)}
                  alt=""
                  className="ds-dash-tile__image"
                  loading="lazy"
                />
              )}
            </div>
          )}
        </DashTile>

        <DashTile
          accent="blue"
          icon={<IconFile size={18} />}
          label="Latest file"
          empty={latestFile ? undefined : "Send from any device to see files here."}
          time={latestFile ? relativeTime(latestFile.created_at) : undefined}
          onDelete={latestFile ? () => void removeFile(latestFile) : undefined}
          foot={
            latestFile ? (
              <div className="ds-dash-tile__file-meta">
                <span className="ds-dash-tile__filename">{latestFile.name}</span>
                <span className="ds-dash-tile__filesize">{formatBytes(latestFile.total_size)}</span>
                <TransferBadge transferMode={latestFile.transfer_mode} className="ds-transfer-badge--inline" />
                <FileRowActions file={latestFile} compact />
              </div>
            ) : undefined
          }
        />
      </div>

      <section className="ds-dash-quick">
        <h2 className="ds-section-title">Quick actions</h2>
        <div className="ds-quick-actions">
          <button type="button" className="ds-quick-action" onClick={() => onNavigate("send")}>
            <span className="ds-quick-action-icon">
              <IconSend size={20} />
            </span>
            <span className="ds-quick-action-label">Send</span>
            <span className="ds-quick-action-hint">Text, photos, files</span>
          </button>
          <button type="button" className="ds-quick-action" onClick={() => onNavigate("files")}>
            <span className="ds-quick-action-icon">
              <IconFile size={20} />
            </span>
            <span className="ds-quick-action-label">All files</span>
            <span className="ds-quick-action-hint">Browse & download</span>
          </button>
          <button type="button" className="ds-quick-action" onClick={() => onNavigate("pinned")}>
            <span className="ds-quick-action-icon">
              <IconPin size={20} />
            </span>
            <span className="ds-quick-action-label">Pinned</span>
            <span className="ds-quick-action-hint">Saved clips</span>
          </button>
        </div>
      </section>
    </div>
  );
}
