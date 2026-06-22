import { useCallback, useRef, useState } from "react";
import { AppButton } from "./AppButton";
import { AppCard } from "./AppCard";
import { IconUpload } from "./Icons";
import { useToast } from "../design/ToastProvider";
import { uploadFiles, type UploadProgress, type UploadResult } from "../lib/upload";
import { copyFileToClipboard, isImageMime } from "../lib/clipboard";
import { formatBytes } from "../lib/format";

interface UploadItem {
  id: string;
  name: string;
  size: number;
  progress: UploadProgress;
}

export function QuickSendFiles() {
  const { toast } = useToast();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const photoInputRef = useRef<HTMLInputElement>(null);
  const cameraInputRef = useRef<HTMLInputElement>(null);
  const [dragActive, setDragActive] = useState(false);
  const [uploads, setUploads] = useState<UploadItem[]>([]);
  const [recentImages, setRecentImages] = useState<UploadResult[]>([]);

  const updateUpload = useCallback((id: string, name: string, size: number, progress: UploadProgress) => {
    setUploads((prev) => {
      const existing = prev.find((u) => u.id === id);
      if (existing) {
        return prev.map((u) => (u.id === id ? { ...u, progress } : u));
      }
      return [...prev, { id, name, size, progress }];
    });
  }, []);

  const handleFiles = useCallback(
    async (fileList: FileList | File[]) => {
      const files = Array.from(fileList);
      if (files.length === 0) return;

      const items = files.map((f) => ({
        id: `${f.name}-${f.size}-${f.lastModified}`,
        name: f.name,
        size: f.size,
      }));

      items.forEach((item) => {
        updateUpload(item.id, item.name, item.size, { progress: 0, status: "uploading" });
      });

      try {
        const { succeeded, failed, results } = await uploadFiles(files, (id, progress) => {
          const item = items.find((i) => i.id === id);
          if (item) updateUpload(id, item.name, item.size, progress);
        });
        const uploadedImages = results.filter(
          (r) => r.status === "success" && r.fileId && isImageMime(r.mimeType),
        );
        if (uploadedImages.length > 0) {
          setRecentImages(uploadedImages);
        }
        if (succeeded > 0) {
          toast(
            succeeded === 1 ? `${files[0].name} uploaded` : `${succeeded} files uploaded`,
            "success",
          );
        }
        if (failed > 0) {
          toast(`${failed} file${failed > 1 ? "s" : ""} failed to upload`, "danger");
        }
        if (succeeded > 0) {
          window.dispatchEvent(new CustomEvent("syncbridge:files-updated"));
          setTimeout(() => {
            setUploads((prev) => prev.filter((u) => u.progress.status !== "success"));
          }, 3000);
        }
      } catch {
        toast("Upload failed", "danger");
      }
    },
    [toast, updateUpload],
  );

  async function copyUploadedImage(result: UploadResult) {
    if (!result.fileId) return;
    try {
      await copyFileToClipboard(result.fileId, result.mimeType);
      toast("Image copied to clipboard", "success");
    } catch {
      toast("Could not copy image", "danger");
    }
  }

  function onDrop(e: React.DragEvent) {
    e.preventDefault();
    setDragActive(false);
    if (e.dataTransfer.files.length) {
      void handleFiles(e.dataTransfer.files);
    }
  }

  return (
    <AppCard>
      <h2 className="ds-card-title">Send Files</h2>
      <p className="ds-card-desc">Drag files here or choose from your device.</p>

      <div
        className={`ds-dropzone ${dragActive ? "ds-dropzone--active" : ""}`}
        onDragOver={(e) => {
          e.preventDefault();
          setDragActive(true);
        }}
        onDragLeave={() => setDragActive(false)}
        onDrop={onDrop}
      >
        <div className="ds-dropzone-icon">
          <IconUpload size={22} />
        </div>
        <p className="ds-dropzone-hint">Drag files here</p>
        <div className="ds-btn-group">
          <AppButton variant="secondary" size="sm" onClick={() => fileInputRef.current?.click()}>
            Choose Files
          </AppButton>
          <AppButton variant="secondary" size="sm" onClick={() => photoInputRef.current?.click()}>
            Choose Photos
          </AppButton>
          <AppButton variant="secondary" size="sm" onClick={() => cameraInputRef.current?.click()}>
            Take Photo
          </AppButton>
        </div>
      </div>

      <input
        ref={fileInputRef}
        type="file"
        multiple
        hidden
        onChange={(e) => {
          if (e.target.files) void handleFiles(e.target.files);
          e.target.value = "";
        }}
      />
      <input
        ref={photoInputRef}
        type="file"
        accept="image/*"
        multiple
        hidden
        onChange={(e) => {
          if (e.target.files) void handleFiles(e.target.files);
          e.target.value = "";
        }}
      />
      <input
        ref={cameraInputRef}
        type="file"
        accept="image/*"
        capture="environment"
        hidden
        onChange={(e) => {
          if (e.target.files) void handleFiles(e.target.files);
          e.target.value = "";
        }}
      />

      {recentImages.length > 0 && (
        <div className="ds-upload-copy-row">
          {recentImages.map((img) => (
            <AppButton
              key={img.fileId}
              variant="secondary"
              size="sm"
              onClick={() => void copyUploadedImage(img)}
            >
              Copy {img.name}
            </AppButton>
          ))}
        </div>
      )}

      {uploads.length > 0 && (
        <ul className="ds-upload-list">
          {uploads.map((item) => (
            <li key={item.id} className="ds-upload-item">
              <div className="ds-upload-item-head">
                <span className="ds-upload-name">{item.name}</span>
                <span className="ds-upload-meta">
                  {item.progress.status === "success"
                    ? "Done"
                    : item.progress.status === "error"
                      ? item.progress.error ?? "Failed"
                      : `${Math.round(item.progress.progress * 100)}%`}
                  {" · "}
                  {formatBytes(item.size)}
                </span>
              </div>
              <div className="ds-progress">
                <div
                  className={`ds-progress-fill ds-progress-fill--${item.progress.status}`}
                  style={{ width: `${item.progress.progress * 100}%` }}
                />
              </div>
            </li>
          ))}
        </ul>
      )}
    </AppCard>
  );
}
