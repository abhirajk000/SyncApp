import { useCallback, useEffect, useState } from "react";
import { FileEntry, fetchFiles, getAccessToken, getServerUrl } from "../api";
import { AppButton, AppEmptyState, AppSkeleton } from "../components";
import { IconImage } from "../components/Icons";
import { copyFileToClipboard, isImageMime } from "../lib/clipboard";
import { useToast } from "../design/ToastProvider";

function ImageThumb({ fileId, name }: { fileId: string; name: string }) {
  const [src, setSrc] = useState<string | null>(null);

  useEffect(() => {
    let revoked: string | null = null;
    async function load() {
      const base = getServerUrl().replace(/\/$/, "");
      const token = getAccessToken();
      if (!token) return;
      const res = await fetch(`${base}/api/v1/files/${fileId}/thumbnail`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) return;
      const blob = await res.blob();
      revoked = URL.createObjectURL(blob);
      setSrc(revoked);
    }
    void load();
    return () => {
      if (revoked) URL.revokeObjectURL(revoked);
    };
  }, [fileId]);

  if (src) {
    return <img src={src} alt={name} className="ds-image-preview ds-image-preview--grid" />;
  }
  return <div className="ds-image-card-placeholder">{name}</div>;
}

export function ImagesPage() {
  const { toast } = useToast();
  const [files, setFiles] = useState<FileEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!getAccessToken()) return;
    setLoading(true);
    try {
      const data = await fetchFiles();
      setFiles(data.files.filter((f) => isImageMime(f.mime_type) && f.status === "ready"));
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function copyImage(fileId: string, mime: string) {
    try {
      await copyFileToClipboard(fileId, mime);
      toast("Image copied", "success");
    } catch {
      toast("Could not copy image", "danger");
    }
  }

  if (loading) return <AppSkeleton rows={4} />;
  if (error) return <p className="ds-error">{error}</p>;

  if (files.length === 0) {
    return (
      <AppEmptyState
        icon={<IconImage size={24} />}
        title="No images yet"
        description="Upload photos from the Clipboard page or another device."
      />
    );
  }

  return (
    <div className="ds-content-narrow">
      <div className="ds-image-grid">
        {files.map((file) => (
          <div key={file.id} className="ds-image-card">
            <ImageThumb fileId={file.id} name={file.name} />
            <div className="ds-image-card-actions">
              <span className="ds-image-card-name">{file.name}</span>
              <AppButton size="sm" onClick={() => void copyImage(file.id, file.mime_type)}>
                Copy Image
              </AppButton>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
