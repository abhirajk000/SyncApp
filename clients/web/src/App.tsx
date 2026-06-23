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
import { NetworkProvider, networkService } from "./design/NetworkProvider";
import { ToastProvider, useToast } from "./design/ToastProvider";
import { PinnedPage } from "./pages/ClipboardPage";
import { FilesPage } from "./pages/FilesPage";
import { HomePage } from "./pages/HomePage";
import { LoginPage } from "./pages/LoginPage";
import { SendPage } from "./pages/SendPage";
import { SettingsPage } from "./pages/SettingsPage";
import { DevicesPage } from "./pages/DevicesPage";
import { SyncBridgeWS, payloadToClipboardEntry } from "./ws";
import { copyEntryToClipboard, imageDataUrl, isImageContentType } from "./lib/clipboard";
import { loadClipboardSettings } from "./lib/clipboardSettings";
import { ensureDeviceId } from "./api";
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
  const [settingsView, setSettingsView] = useState<"main" | "network" | "devices">("main");
  const [liveConnected, setLiveConnected] = useState(false);
  const showConnected = useStableConnection(liveConnected);
  const [latestPopup, setLatestPopup] = useState<ClipboardEntry | null>(null);
  const [copied, setCopied] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const closeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const popupShownThisSession = useRef(false);
  const { toast } = useToast();

  const onAuthed = useCallback(async () => {
    setAuthed(true);
    if (popupShownThisSession.current) return;
    try {
      const entry = await fetchCurrentClipboard();
      setLatestPopup(entry);
      popupShownThisSession.current = true;
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
  const lastLocalCopyAtRef = useRef(0);
  const lastAppliedHashRef = useRef("");

  useEffect(() => {
    if (!authed) return;
    const onCopy = () => {
      lastLocalCopyAtRef.current = Date.now();
    };
    document.addEventListener("copy", onCopy);
    return () => document.removeEventListener("copy", onCopy);
  }, [authed]);

  useEffect(() => {
    if (!authed) {
      ws.disconnect();
      networkService.stop();
      setLiveConnected(false);
      return;
    }

    networkService.start();
    networkService.setWsConnected(false);

    ws.onConnectionChange = (connected) => {
      setLiveConnected(connected);
      networkService.setWsConnected(connected);
    };
    ws.onMessage = (type, payload) => {
      if (type === "signal.peer") {
        networkService.handleSignalPeer(payload);
      }
      if (type === "clipboard.new") {
        const entry = payloadToClipboardEntry(payload);
        if (entry) {
          const peerIds = new Set(networkService.getSnapshot().peers.map((p) => p.device_id));
          entry.transfer_route = peerIds.has(entry.source_device_id) ? "direct_lan" : "relay";
          window.dispatchEvent(new CustomEvent("syncbridge:clipboard-new", { detail: entry }));
          networkService.markSync();

          const localId = ensureDeviceId();
          if (entry.source_device_id !== localId) {
            setLatestPopup((prev) => {
              if (popupShownThisSession.current && prev === null) return prev;
              return entry;
            });
            if (!popupShownThisSession.current) {
              popupShownThisSession.current = true;
            }
          }

          const settings = loadClipboardSettings();
          if (settings.showClipboardNotifications && entry.source_device_id !== localId) {
            toastRef.current("Clipboard updated", "success");
          }

          const hash = entry.content || entry.id;
          const recentLocalCopy = Date.now() - lastLocalCopyAtRef.current < 4000;
          const shouldApply =
            settings.autoApplyRemoteClipboard &&
            entry.source_device_id !== localId &&
            hash !== lastAppliedHashRef.current &&
            !recentLocalCopy &&
            document.visibilityState === "visible";

          if (shouldApply) {
            void copyEntryToClipboard(entry)
              .then(() => {
                lastAppliedHashRef.current = hash;
              })
              .catch(() => {
                /* Browser may block clipboard without user gesture — manual copy still available */
              });
          }
        }
      }
      if (type === "clipboard.pin") {
        window.dispatchEvent(new CustomEvent("syncbridge:clipboard-pin", { detail: payload }));
        networkService.markSync();
      }
      if (type === "file.ready" || type === "file.progress") {
        networkService.markSync();
        window.dispatchEvent(new CustomEvent("syncbridge:files-updated"));
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
      networkService.stop();
      setLiveConnected(false);
    };
  }, [authed]);

  function logout() {
    ws.disconnect();
    clearSession();
    setAuthed(false);
    setLatestPopup(null);
    popupShownThisSession.current = false;
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

  function handleRefresh() {
    if (refreshing) return;
    setRefreshing(true);
    window.dispatchEvent(new CustomEvent("syncbridge:app-refresh", { detail: { manual: true } }));
    void networkService.refresh().finally(() => setRefreshing(false));
  }

  function renderPage() {
    switch (nav) {
      case "clipboard":
        return <HomePage />;
      case "pinned":
        return <PinnedPage />;
      case "send":
        return <SendPage />;
      case "files":
        return <FilesPage />;
      case "settings":
        if (settingsView === "devices") {
          return <DevicesPage onBack={() => setSettingsView("main")} />;
        }
        return (
          <SettingsPage
            onLogout={logout}
            onOpenDevices={() => setSettingsView("devices")}
          />
        );
    }
  }

  return (
    <AppLayout>
      <div className="ds-main">
        <AppTopBar connected={showConnected} refreshing={refreshing} onRefresh={handleRefresh} />
        <main className="ds-content">{renderPage()}</main>
      </div>
      <AppBottomNav
        active={nav}
        onNavigate={(id) => {
          if (id !== "settings") setSettingsView("main");
          setNav(id);
        }}
      />
      <AppModal
        open={!!latestPopup}
        title="Latest Clipboard"
        onClose={() => {
          setLatestPopup(null);
          popupShownThisSession.current = true;
        }}
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
      <NetworkProvider>
        <ToastProvider>
          <div className="ds-app">
            <AppShell />
          </div>
        </ToastProvider>
      </NetworkProvider>
    </ThemeProvider>
  );
}
