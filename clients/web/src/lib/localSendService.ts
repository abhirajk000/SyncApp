/** Local Send service — web stub (native apps required for LAN P2P). */

export type LocalSendStatus = "native_required" | "ready";

export type LocalSendSnapshot = {
  status: LocalSendStatus;
  platform: string;
  message: string;
};

const NATIVE_MESSAGE =
  "Local Send uses mDNS discovery and direct TCP between devices on your Wi-Fi. Use SyncBridge on Mac, Android, or iPhone.";

class LocalSendService {
  private listeners = new Set<() => void>();
  private started = false;
  private snapshot: LocalSendSnapshot = {
    status: "native_required",
    platform: detectPlatform(),
    message: NATIVE_MESSAGE,
  };

  start() {
    if (this.started) return;
    this.started = true;
    this.emit();
  }

  stop() {
    if (!this.started) return;
    this.started = false;
    this.emit();
  }

  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  getSnapshot = (): LocalSendSnapshot => this.snapshot;

  private emit() {
    for (const listener of this.listeners) listener();
  }
}

function detectPlatform(): string {
  const ua = navigator.userAgent;
  if (/iPhone|iPad|iPod/i.test(ua)) return "ios";
  if (/Android/i.test(ua)) return "android";
  if (/Mac/i.test(ua)) return "macos";
  if (/Windows/i.test(ua)) return "windows";
  return "web";
}

export const localSendService = new LocalSendService();
