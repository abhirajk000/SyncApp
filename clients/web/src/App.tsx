import { useCallback, useEffect, useRef, useState } from "react";
import {
  ClipboardEntry,
  clearSession,
  fetchClipboardHistory,
  fetchCurrentClipboard,
  fetchFiles,
  isAuthenticated,
  restoreSession,
} from "./api";
import {
  AppHeader,
  AppLayout,
  AppModal,
  AppSidebar,
  type NavId,
} from "./components";
import { ThemeProvider } from "./design/ThemeProvider";
import { ToastProvider, useToast } from "./design/ToastProvider";
import { ClipboardPage } from "./pages/ClipboardPage";
import { DashboardPage } from "./pages/DashboardPage";
import { DevicesPage } from "./pages/DevicesPage";
import { FilesPage } from "./pages/FilesPage";
import { ImagesPage } from "./pages/ImagesPage";
import { LoginPage } from "./pages/LoginPage";
import { SettingsPage } from "./pages/SettingsPage";
import { SyncBridgeWS, payloadToClipboardEntry } from "./ws";
import { copyEntryToClipboard, imageDataUrl, isImageContentType } from "./lib/clipboard";
import { relativeTime } from "./lib/format";
import { AppButton } from "./components";

const ws = new SyncBridgeWS();

const PAGE_TITLES: Record<NavId, string> = {
  dashboard: "Dashboard",
  clipboard: "Clipboard",
  pinned: "Pinned",
  files: "Files",
  images: "Images",
  devices: "Devices",
  settings: "Settings",
};

function AppShell() {
  const [booting, setBooting] = useState(true);
  const [authed, setAuthed] = useState(false);
  const [nav, setNav] = useState<NavId>("dashboard");
  const [liveConnected, setLiveConnected] = useState(false);
  const [latestPopup, setLatestPopup] = useState<ClipboardEntry | null>(null);
  const [stats, setStats] = useState({ clipboard: 0, pinned: 0, files: 0 });
  const [copied, setCopied] = useState(false);
  const closeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const { toast } = useToast();

  const refreshStats = useCallback(async () => {
    try {
      const [clip, fileData] = await Promise.all([
        fetchClipboardHistory(),
        fetchFiles(),
      ]);
      setStats({
        clipboard: clip.entries.length,
        pinned: clip.entries.filter((e) => e.pinned).length,
        files: fileData.files.length,
      });
    } catch {
      /* ignore */
    }
  }, []);

  const onAuthed = useCallback(async () => {
    setAuthed(true);
    try {
      const entry = await fetchCurrentClipboard();
      setLatestPopup(entry);
    } catch {
      /* no clipboard */
    }
    ws.connect();
    await refreshStats();
  }, [refreshStats]);

  useEffect(() => {
    let cancelled = false;
    async function boot() {
      if (isAuthenticated()) {
        const ok = await restoreSession();
        if (!cancelled && ok) {
          await onAuthed();
        }
      }
      if (!cancelled) setBooting(false);
    }
    void boot();
    return () => {
      cancelled = true;
    };
  }, [onAuthed]);

  useEffect(() => {
    if (!authed) {
      ws.disconnect();
      return;
    }
    ws.onConnectionChange = setLiveConnected;
    ws.onMessage = (type, payload) => {
      if (type === "clipboard.new") {
        const entry = payloadToClipboardEntry(payload);
        if (entry) {
          window.dispatchEvent(new CustomEvent("syncbridge:clipboard-new", { detail: entry }));
          toast("Clipboard updated", "success");
        }
      }
      if (type === "clipboard.pin") {
        window.dispatchEvent(new CustomEvent("syncbridge:clipboard-pin", { detail: payload }));
      }
    };
    ws.connect();
    refreshStats();
    return () => ws.disconnect();
  }, [authed, refreshStats, toast]);

  function logout() {
    ws.disconnect();
    clearSession();
    setAuthed(false);
    setLatestPopup(null);
  }

  async function copyLatest() {
    if (!latestPopup) return;
    try {
      await copyEntryToClipboard(latestPopup);
      setCopied(true);
      toast(
        isImageContentType(latestPopup.content_type) ? "Image copied" : "Copied to clipboard",
        "success",
      );
      closeTimer.current = setTimeout(() => {
        setLatestPopup(null);
        setCopied(false);
      }, 800);
    } catch {
      toast("Could not copy", "danger");
    }
  }

  if (booting) {
    return (
      <div className="ds-login-wrap ds-app">
        <p className="ds-subtitle">Loading…</p>
      </div>
    );
  }

  if (!authed) {
    return <LoginPage onSuccess={onAuthed} />;
  }

  function renderPage() {
    switch (nav) {
      case "dashboard":
        return (
          <DashboardPage
            clipboardCount={stats.clipboard}
            pinnedCount={stats.pinned}
            fileCount={stats.files}
            connected={liveConnected}
          />
        );
      case "clipboard":
        return <ClipboardPage />;
      case "pinned":
        return <ClipboardPage pinnedOnly />;
      case "files":
        return <FilesPage />;
      case "images":
        return <ImagesPage />;
      case "devices":
        return <DevicesPage />;
      case "settings":
        return <SettingsPage />;
    }
  }

  return (
    <AppLayout>
      <AppSidebar active={nav} onNavigate={setNav} onLogout={logout} />
      <div className="ds-main">
        <AppHeader
          title={PAGE_TITLES[nav]}
          subtitle="SyncBridge web dashboard"
          connected={liveConnected}
        />
        <main className="ds-content">{renderPage()}</main>
      </div>
      <AppModal
        open={!!latestPopup}
        title="Latest Clipboard"
        onClose={() => setLatestPopup(null)}
      >
        {latestPopup && (
          <>
            <p className="ds-subtitle" style={{ marginBottom: "var(--space-4)" }}>
              {relativeTime(latestPopup.created_at)}
            </p>
            {isImageContentType(latestPopup.content_type) ? (
              <img
                src={imageDataUrl(latestPopup)}
                alt="Clipboard"
                className="ds-image-preview"
                style={{ marginBottom: "var(--space-4)", cursor: "pointer" }}
                onClick={() => void copyLatest()}
              />
            ) : (
              <AppButton variant="ghost" block onClick={copyLatest} style={{ textAlign: "left", whiteSpace: "pre-wrap" }}>
                {latestPopup.content}
              </AppButton>
            )}
            <AppButton block onClick={copyLatest} style={{ marginTop: "var(--space-3)" }}>
              {isImageContentType(latestPopup.content_type) ? "Copy Image" : "Copy"}
            </AppButton>
            {copied && (
              <p style={{ textAlign: "center", color: "var(--color-success)", marginTop: "var(--space-3)" }}>
                ✓ Copied
              </p>
            )}
          </>
        )}
      </AppModal>
    </AppLayout>
  );
}

export default function App() {
  return (
    <ThemeProvider>
      <ToastProvider>
        <div className="ds-app">
          <AppShell />
        </div>
      </ToastProvider>
    </ThemeProvider>
  );
}
