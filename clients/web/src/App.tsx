import { useCallback, useEffect, useState } from "react";
import {
  ClipboardEntry,
  FileEntry,
  clearSession,
  fetchClipboardHistory,
  fetchFiles,
  getAccessToken,
  getServerUrl,
  isAuthenticated,
  pinClipboard,
  pinFile,
  setServerUrl,
  unlock,
} from "./api";

type Tab = "clipboard" | "files";

export default function App() {
  const [authed, setAuthed] = useState(isAuthenticated());
  const [tab, setTab] = useState<Tab>("clipboard");

  if (!authed) {
    return <LoginScreen onSuccess={() => setAuthed(true)} />;
  }

  return (
    <div className="app">
      <header className="header">
        <h1>SyncBridge</h1>
        <nav className="tabs">
          <button
            type="button"
            className={tab === "clipboard" ? "active" : ""}
            onClick={() => setTab("clipboard")}
          >
            Clipboard
          </button>
          <button
            type="button"
            className={tab === "files" ? "active" : ""}
            onClick={() => setTab("files")}
          >
            Files
          </button>
        </nav>
        <button
          type="button"
          className="logout"
          onClick={() => {
            clearSession();
            setAuthed(false);
          }}
        >
          Log out
        </button>
      </header>
      <main>
        {tab === "clipboard" ? <ClipboardView /> : <FilesView />}
      </main>
    </div>
  );
}

function LoginScreen({ onSuccess }: { onSuccess: () => void }) {
  const [serverUrl, setServerUrlInput] = useState(getServerUrl());
  const [pin, setPin] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function submit() {
    setError(null);
    setLoading(true);
    try {
      setServerUrl(serverUrl);
      await unlock(pin);
      setPin("");
      onSuccess();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unlock failed");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login">
      <h1>SyncBridge</h1>
      <p className="muted">Enter your PIN to unlock</p>
      <label>
        Server URL
        <input
          type="url"
          value={serverUrl}
          onChange={(e) => setServerUrlInput(e.target.value)}
          placeholder="http://localhost:8080"
        />
      </label>
      <label>
        PIN
        <input
          type="password"
          value={pin}
          onChange={(e) => setPin(e.target.value)}
          inputMode="numeric"
          autoComplete="off"
        />
      </label>
      {error && <p className="error">{error}</p>}
      <button type="button" disabled={loading || !pin} onClick={submit}>
        {loading ? "Unlocking…" : "Unlock"}
      </button>
      <p className="hint">Trusted devices skip this screen for 7 days.</p>
    </div>
  );
}

function ClipboardView() {
  const [entries, setEntries] = useState<ClipboardEntry[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (!getAccessToken()) return;
    setLoading(true);
    setError(null);
    try {
      const data = await fetchClipboardHistory();
      setEntries(data.entries);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load clipboard");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function togglePin(entry: ClipboardEntry) {
    try {
      await pinClipboard(entry.id, !entry.pinned);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Pin failed");
    }
  }

  const temporary = entries.filter((e) => !e.pinned);
  const pinned = entries.filter((e) => e.pinned);

  return (
    <div className="view">
      <div className="view-toolbar">
        <button type="button" onClick={load} disabled={loading}>Refresh</button>
      </div>
      {error && <p className="error">{error}</p>}
      {loading && <p className="muted">Loading…</p>}
      <ClipboardSection title="Temporary" entries={temporary} empty="No temporary clipboard items" onPin={togglePin} />
      <ClipboardSection title="Pinned" entries={pinned} empty="No pinned clipboard items" onPin={togglePin} />
    </div>
  );
}

function FilesView() {
  const [files, setFiles] = useState<FileEntry[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

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
  }, [load]);

  async function togglePin(file: FileEntry) {
    try {
      await pinFile(file.id, !file.is_pinned);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Pin failed");
    }
  }

  const temporary = files.filter((f) => !f.is_pinned);
  const pinned = files.filter((f) => f.is_pinned);

  return (
    <div className="view">
      <div className="view-toolbar">
        <button type="button" onClick={load} disabled={loading}>Refresh</button>
      </div>
      {error && <p className="error">{error}</p>}
      {loading && <p className="muted">Loading…</p>}
      <FilesSection title="Temporary" files={temporary} empty="No temporary files" onPin={togglePin} />
      <FilesSection title="Pinned" files={pinned} empty="No pinned files" onPin={togglePin} />
    </div>
  );
}

function ClipboardSection({
  title,
  entries,
  empty,
  onPin,
}: {
  title: string;
  entries: ClipboardEntry[];
  empty: string;
  onPin: (entry: ClipboardEntry) => void;
}) {
  return (
    <section className="section">
      <h2>{title}</h2>
      {entries.length === 0 ? (
        <p className="muted">{empty}</p>
      ) : (
        <ul className="list">
          {entries.map((entry) => (
            <li key={entry.id} className="list-item">
              <div className="list-body">
                <span className="primary">{entry.content}</span>
                <span className="meta">{entry.content_type}</span>
              </div>
              <button type="button" className="pin-btn" onClick={() => onPin(entry)}>
                {entry.pinned ? "Unpin" : "Pin"}
              </button>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function FilesSection({
  title,
  files,
  empty,
  onPin,
}: {
  title: string;
  files: FileEntry[];
  empty: string;
  onPin: (file: FileEntry) => void;
}) {
  return (
    <section className="section">
      <h2>{title}</h2>
      {files.length === 0 ? (
        <p className="muted">{empty}</p>
      ) : (
        <ul className="list">
          {files.map((file) => (
            <li key={file.id} className="list-item">
              <div className="list-body">
                <span className="primary">{file.name}</span>
                <span className="meta">
                  {formatBytes(file.total_size)} · {file.status}
                </span>
              </div>
              <button type="button" className="pin-btn" onClick={() => onPin(file)}>
                {file.is_pinned ? "Unpin" : "Pin"}
              </button>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(1)} MB`;
}
