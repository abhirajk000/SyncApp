import { useEffect, useRef, useState } from "react";
import type { FileEntry } from "../api";
import {
  Archive,
  Copy,
  Download,
  File,
  FileText,
  FileVideo,
  Loader2,
  MoreHorizontal,
  Pin,
  PinOff,
  X,
} from "lucide-react";
import { copyFileToClipboard, isImageMime } from "../lib/clipboard";
import {
  copyTextFile,
  downloadFile,
  fetchFileBlob,
  fetchFileThumbnail,
  getFileExtension,
  getFilePreviewKind,
  isTextMime,
  TEXT_PREVIEW_MAX_BYTES,
  type FilePreviewKind,
} from "../lib/files";
import { useToast } from "../design/ToastProvider";
import { ItemDeleteButton } from "./ItemDeleteButton";

interface Props {
  file: FileEntry;
  onPin: (file: FileEntry) => void;
  onDelete?: (file: FileEntry) => void;
}

function TypeIcon({ kind, size = 40 }: { kind: FilePreviewKind; size?: number }) {
  switch (kind) {
    case "text":
      return <FileText size={size} strokeWidth={1.5} />;
    case "video":
      return <FileVideo size={size} strokeWidth={1.5} />;
    case "pdf":
    case "document":
      return <FileText size={size} strokeWidth={1.5} />;
    case "archive":
      return <Archive size={size} strokeWidth={1.5} />;
    default:
      return <File size={size} strokeWidth={1.5} />;
  }
}

function FilePreviewContent({ file }: { file: FileEntry }) {
  const kind = getFilePreviewKind(file.mime_type, file.name);
  const ext = getFileExtension(file.name);
  const [imageSrc, setImageSrc] = useState<string | null>(null);
  const [textPreview, setTextPreview] = useState<string | null>(null);
  const [loading, setLoading] = useState(file.status === "ready");
  const [useTypeFallback, setUseTypeFallback] = useState(false);

  useEffect(() => {
    if (file.status !== "ready") {
      setLoading(false);
      return;
    }

    let objectUrl: string | null = null;
    let cancelled = false;

    async function loadImage() {
      const thumb = await fetchFileThumbnail(file.id);
      if (cancelled) return;
      if (thumb) {
        objectUrl = URL.createObjectURL(thumb);
        setImageSrc(objectUrl);
      } else {
        setUseTypeFallback(true);
      }
      setLoading(false);
    }

    async function loadText() {
      if (file.total_size > TEXT_PREVIEW_MAX_BYTES) {
        setUseTypeFallback(true);
        setLoading(false);
        return;
      }
      try {
        const blob = await fetchFileBlob(file.id);
        if (cancelled) return;
        const snippet = await blob.slice(0, 4096).text();
        setTextPreview(snippet.slice(0, 1400));
      } catch {
        setUseTypeFallback(true);
      }
      setLoading(false);
    }

    if (kind === "image") void loadImage();
    else if (kind === "text") void loadText();
    else {
      setLoading(false);
      setUseTypeFallback(true);
    }

    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [file.id, file.status, file.total_size, file.mime_type, kind]);

  if (file.status !== "ready") {
    return (
      <div className="ds-file-preview-state">
        <Loader2 size={28} className="ds-spin" strokeWidth={1.75} />
        <span>Uploading</span>
      </div>
    );
  }

  if (loading) {
    return <div className="ds-file-preview-skeleton" aria-hidden />;
  }

  if (kind === "image" && imageSrc && !useTypeFallback) {
    return <img src={imageSrc} alt="" className="ds-file-preview-image" draggable={false} loading="lazy" />;
  }

  if (kind === "text" && textPreview && !useTypeFallback) {
    return (
      <div className="ds-file-preview-doc">
        <pre>{textPreview}</pre>
      </div>
    );
  }

  return (
    <div className="ds-file-preview-type">
      <TypeIcon kind={kind} />
      {ext && <span className="ds-file-preview-ext">{ext}</span>}
    </div>
  );
}

export function FileGridCard({ file, onPin, onDelete }: Props) {
  const { toast } = useToast();
  const [menuOpen, setMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const ready = file.status === "ready";

  useEffect(() => {
    if (!menuOpen) return;
    function onPointerDown(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false);
      }
    }
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, [menuOpen]);

  async function onDownload() {
    setMenuOpen(false);
    try {
      await downloadFile(file.id, file.name);
      toast("Download started", "success");
    } catch {
      toast("Download failed", "danger");
    }
  }

  async function onCopy() {
    setMenuOpen(false);
    try {
      if (isImageMime(file.mime_type)) {
        await copyFileToClipboard(file.id, file.mime_type);
        toast("Image copied", "success");
      } else if (isTextMime(file.mime_type)) {
        await copyTextFile(file.id);
        toast("Copied to clipboard", "success");
      }
    } catch {
      toast("Could not copy", "danger");
    }
  }

  const canCopy = ready && (isImageMime(file.mime_type) || isTextMime(file.mime_type));

  function handleDelete() {
    if (!onDelete) return;
    setMenuOpen(false);
    onDelete(file);
  }

  return (
    <article className="ds-file-grid-item">
      <div className="ds-file-grid-preview-wrap" ref={menuRef}>
        <div className="ds-file-preview">
          <FilePreviewContent file={file} />
        </div>
        {onDelete && (
          <ItemDeleteButton overlay onClick={handleDelete} label={`Delete ${file.name}`} />
        )}
        <button
          type="button"
          className="ds-file-grid-menu-btn"
          aria-label="File actions"
          aria-expanded={menuOpen}
          onClick={() => setMenuOpen((open) => !open)}
        >
          <MoreHorizontal size={16} strokeWidth={2} />
        </button>
        {menuOpen && (
          <div className="ds-file-grid-menu" role="menu">
            {ready && (
              <button type="button" role="menuitem" onClick={() => void onDownload()}>
                <Download size={16} strokeWidth={1.75} />
                Download
              </button>
            )}
            {canCopy && (
              <button type="button" role="menuitem" onClick={() => void onCopy()}>
                <Copy size={16} strokeWidth={1.75} />
                Copy
              </button>
            )}
            <button
              type="button"
              role="menuitem"
              onClick={() => {
                setMenuOpen(false);
                onPin(file);
              }}
            >
              {file.is_pinned ? (
                <>
                  <PinOff size={16} strokeWidth={1.75} />
                  Unpin
                </>
              ) : (
                <>
                  <Pin size={16} strokeWidth={1.75} />
                  Pin
                </>
              )}
            </button>
            {onDelete && (
              <button type="button" role="menuitem" onClick={handleDelete}>
                <X size={16} strokeWidth={1.75} />
                Delete
              </button>
            )}
          </div>
        )}
      </div>
      <p className="ds-file-grid-name" title={file.name}>
        {file.name}
      </p>
    </article>
  );
}
