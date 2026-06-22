import { useCallback, useEffect, useState } from "react";
import { FileEntry, fetchFiles, getAccessToken, pinFile } from "../api";
import { AppButton, AppEmptyState, AppSection, AppSkeleton } from "../components";
import { FileGridCard } from "../components/FileGridCard";
import { FileRowActions } from "../components/FileRowActions";
import { IconFolder } from "../components/Icons";
import { formatBytes, relativeTime } from "../lib/format";

export function FilesPage() {
  const [files, setFiles] = useState<FileEntry[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<"temporary" | "pinned">("temporary");

  const load = useCallback(async () => {
    if (!getAccessToken()) return;
    setLoading(true);
    setError(null);
    try {
      const data = await fetchFiles();
      setFiles(data.files);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load files");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
    function onFilesUpdated() {
      void load();
    }
    window.addEventListener("syncbridge:files-updated", onFilesUpdated);
    return () => window.removeEventListener("syncbridge:files-updated", onFilesUpdated);
  }, [load]);

  async function togglePin(file: FileEntry) {
    try {
      await pinFile(file.id, !file.is_pinned);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Pin failed");
    }
  }

  const filtered = files.filter((f) => (tab === "pinned" ? f.is_pinned : !f.is_pinned));

  if (loading && files.length === 0) return <AppSkeleton rows={5} />;

  return (
    <div className="ds-content-narrow">
      <div style={{ display: "flex", gap: "var(--space-2)", marginBottom: "var(--space-4)" }}>
        <AppButton variant={tab === "temporary" ? "primary" : "ghost"} size="sm" onClick={() => setTab("temporary")}>
          Temporary
        </AppButton>
        <AppButton variant={tab === "pinned" ? "primary" : "ghost"} size="sm" onClick={() => setTab("pinned")}>
          Pinned
        </AppButton>
      </div>
      {error && <p className="ds-error" style={{ marginBottom: "var(--space-4)" }}>{error}</p>}
      {filtered.length === 0 ? (
        <AppEmptyState
          icon={<IconFolder size={24} />}
          title={`No ${tab} files`}
          description="Transfer files from a connected device to see them here."
        />
      ) : tab === "temporary" ? (
        <AppSection title="Temporary files">
          <div className="ds-file-grid">
            {filtered.map((file) => (
              <FileGridCard key={file.id} file={file} onPin={togglePin} />
            ))}
          </div>
        </AppSection>
      ) : (
        <AppSection title="Pinned files">
          <ul className="ds-list">
            {filtered.map((file) => (
              <li key={file.id} className="ds-list-item">
                <div className="ds-list-body">
                  <span className="ds-list-primary">{file.name}</span>
                  <span className="ds-list-meta">
                    {formatBytes(file.total_size)} · {file.status} · {relativeTime(file.created_at)}
                  </span>
                </div>
                <div className="ds-list-actions">
                  <FileRowActions file={file} />
                  <AppButton variant="ghost" size="sm" onClick={() => togglePin(file)}>
                    {file.is_pinned ? "Unpin" : "Pin"}
                  </AppButton>
                </div>
              </li>
            ))}
          </ul>
        </AppSection>
      )}
    </div>
  );
}
