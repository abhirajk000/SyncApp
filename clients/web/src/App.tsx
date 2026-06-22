import { useCallback, useEffect, useRef, useState } from "react";
import {
  ClipboardEntry,
  clearSession,
  fetchCurrentClipboard,
  isAuthenticated,
  restoreSession,
} from "./api";
import {
  AppButton,
  AppBottomNav,
  AppLayout,
  AppLoader,
  AppModal,
  type NavId,
  AppTopBar,
} from "./components";
import { ThemeProvider } from "./design/ThemeProvider";
import { ToastProvider, useToast } from "./design/ToastProvider";
import { PinnedPage } from "./pages/ClipboardPage";
import { FilesPage } from "./pages/FilesPage";
import { HomePage } from "./pages/HomePage";
import { LoginPage } from "./pages/LoginPage";
import { SendPage } from "./pages/SendPage";
import { SettingsPage } from "./pages/SettingsPage";
import { SyncBridgeWS, payloadToClipboardEntry } from "./ws";
import { copyEntryToClipboard, imageDataUrl, isImageContentType } from "./lib/clipboard";
import { Check } from "lucide-react";
import { relativeTime } from "./lib/format";

const ws = new SyncBridgeWS();

function useStableConnection(live: boolean): boolean {
  const [stable, setStable] = useState(live);
  useEffect(() => {
    if (live) {
      setStable(true);
      return;
    }
    const timer = setTimeout(() => setStable(false), 2500);
    return () => clearTimeout(timer);
  }, [live]);
  return stable;
}

function AppShell() {
  const [booting, setBooting] = useState(true);
  const [authed, setAuthed] = useState(false);
  const [nav, setNav] = useState<NavId>("clipboard");
  const [liveConnected, setLiveConnected] = useState(false);
  const showConnected = useStableConnection(liveConnected);
  const [latestPopup, setLatestPopup] = useState<ClipboardEntry | null>(null);
  const [copied, setCopied] = useState(false);
  const closeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const { toast } = useToast();

  const onAuthed = useCallback(async () => {
    setAuthed(true);
    try {
      const entry = await fetchCurrentClipboard();
      setLatestPopup(entry);
    } catch {
      /* no clipboard */
    }
  }, []);

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

  const toastRef = useRef(toast);
  toastRef.current = toast;

  useEffect(() => {
    if (!authed) {
      ws.disconnect();
      setLiveConnected(false);
      return;
    }

    ws.onConnectionChange = setLiveConnected;
    ws.onMessage = (type, payload) => {
      if (type === "clipboard.new") {
        const entry = payloadToClipboardEntry(payload);
        if (entry) {
          window.dispatchEvent(new CustomEvent("syncbridge:clipboard-new", { detail: entry }));
          toastRef.current("Clipboard updated", "success");
        }
      }
      if (type === "clipboard.pin") {
        window.dispatchEvent(new CustomEvent("syncbridge:clipboard-pin", { detail: payload }));
      }
    };
    ws.connect();

    const onVisible = () => {
      if (document.visibilityState === "visible") ws.connect();
    };
    document.addEventListener("visibilitychange", onVisible);

    return () => {
      document.removeEventListener("visibilitychange", onVisible);
      ws.disconnect();
      setLiveConnected(false);
    };
  }, [authed]);

  function logout() {
    ws.disconnect();
    clearSession();
    setAuthed(false);
    setLatestPopup(null);
    setNav("clipboard");
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
    return <AppLoader label="Starting up…" />;
  }

  if (!authed) {
    return <LoginPage onSuccess={onAuthed} />;
  }

  function renderPage() {
    switch (nav) {
      case "clipboard":
        return <HomePage onNavigate={setNav} />;
      case "pinned":
        return <PinnedPage />;
      case "send":
        return <SendPage />;
      case "files":
        return <FilesPage />;
      case "settings":
        return <SettingsPage onLogout={logout} />;
    }
  }

  return (
    <AppLayout>
      <div className="ds-main">
        <AppTopBar connected={showConnected} />
        <main className="ds-content">{renderPage()}</main>
      </div>
      <AppBottomNav active={nav} onNavigate={setNav} />
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
              <p className="ds-copied-msg">
                <Check size={16} strokeWidth={2.5} />
                Copied
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
