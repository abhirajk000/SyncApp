import { useCallback, useEffect, useState } from "react";
import { FileEntry, deleteFileEntry, fetchFiles, getAccessToken, pinFile } from "../api";
import { AppButton, AppEmptyState, AppSection, AppSkeleton, AppTabs } from "../components";
import { FileGridCard } from "../components/FileGridCard";
import { FileRowActions } from "../components/FileRowActions";
import { ItemDeleteButton } from "../components/ItemDeleteButton";
import { formatBytes, relativeTime } from "../lib/format";
import { useToast } from "../design/ToastProvider";
import { TransferBadge } from "../components/TransferBadge";

export function FilesPage() {
  const { toast } = useToast();
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
    function onAppRefresh() {
      void load();
    }
    window.addEventListener("syncbridge:files-updated", onFilesUpdated);
    window.addEventListener("syncbridge:app-refresh", onAppRefresh);
    return () => {
      window.removeEventListener("syncbridge:files-updated", onFilesUpdated);
      window.removeEventListener("syncbridge:app-refresh", onAppRefresh);
    };
  }, [load]);

  async function togglePin(file: FileEntry) {
    try {
      await pinFile(file.id, !file.is_pinned);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Pin failed");
    }
  }

  async function remove(file: FileEntry) {
    try {
      await deleteFileEntry(file);
      setFiles((prev) => prev.filter((f) => f.id !== file.id));
      window.dispatchEvent(new CustomEvent("syncbridge:files-updated"));
      toast("Deleted", "success");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Delete failed");
      toast("Could not delete", "danger");
    }
  }

  const filtered = files.filter((f) => (tab === "pinned" ? f.is_pinned : !f.is_pinned));

  if (loading && files.length === 0) return <AppSkeleton rows={5} />;

  return (
    <div className="sb-page-stack">
      <div>
        <h1 className="ds-page-title">Files</h1>
        <p className="ds-page-lead">Temporary transfers and pinned files from your devices.</p>
      </div>
      <AppTabs
        tabs={[
          { id: "temporary", label: "Temporary" },
          { id: "pinned", label: "Pinned" },
        ]}
        active={tab}
        onChange={(id) => setTab(id as "temporary" | "pinned")}
      />
      {error && <p className="ds-error ds-error--spaced">{error}</p>}
      {filtered.length === 0 ? (
        <AppEmptyState
          illustration="files"
          title={`No ${tab} files`}
          description="Transfer files from a connected device to see them here."
        />
      ) : tab === "temporary" ? (
        <AppSection title="Temporary files">
          <div className="ds-file-grid">
            {filtered.map((file) => (
              <FileGridCard key={file.id} file={file} onPin={togglePin} onDelete={remove} />
            ))}
          </div>
        </AppSection>
      ) : (
        <AppSection title="Pinned files">
          <ul className="sb-oneui-group">
            {filtered.map((file) => (
              <li key={file.id} className="sb-oneui-group__item">
                <div className="sb-oneui-group__body">
                  <span className="ds-list-primary">{file.name}</span>
                  <span className="ds-list-meta">
                    {formatBytes(file.total_size)} · {file.status} · {relativeTime(file.created_at)}
                  </span>
                  <TransferBadge transferMode={file.transfer_mode} className="ds-transfer-badge--inline" />
                </div>
                <div className="ds-list-actions">
                  <FileRowActions file={file} />
                  <AppButton variant="ghost" size="sm" onClick={() => togglePin(file)}>
                    {file.is_pinned ? "Unpin" : "Pin"}
                  </AppButton>
                  <ItemDeleteButton onClick={() => void remove(file)} />
                </div>
              </li>
            ))}
          </ul>
        </AppSection>
      )}
    </div>
  );
}
