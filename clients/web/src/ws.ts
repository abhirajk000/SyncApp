import { getAccessToken, getServerUrl } from "./api";

export interface WSClipboardNew {
  entry_id: string;
  content_type: string;
  content: string;
  source_device_id: string;
  created_at: string;
  pinned?: boolean;
  expires_at?: string;
}

type MessageHandler = (type: string, payload: unknown) => void;
type ConnectionHandler = (connected: boolean) => void;

export class SyncBridgeWS {
  private ws: WebSocket | null = null;
  private heartbeat: ReturnType<typeof setInterval> | null = null;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private backoffIndex = 0;
  private readonly backoffSteps = [1000, 2000, 5000, 10000];
  private stopped = true;
  /** Ignore onclose from sockets replaced by a newer connect() call. */
  private generation = 0;

  onMessage: MessageHandler | null = null;
  onConnectionChange: ConnectionHandler | null = null;

  connect(): void {
    this.stopped = false;
    if (
      this.ws?.readyState === WebSocket.OPEN ||
      this.ws?.readyState === WebSocket.CONNECTING
    ) {
      return;
    }
    this.open();
  }

  disconnect(): void {
    this.stopped = true;
    this.generation += 1;
    this.clearTimers();
    if (this.ws) {
      this.ws.onopen = null;
      this.ws.onclose = null;
      this.ws.onerror = null;
      this.ws.onmessage = null;
      this.ws.close();
      this.ws = null;
    }
    this.onConnectionChange?.(false);
  }

  private wsUrl(): string {
    const base = getServerUrl().replace(/\/$/, "");
    const token = getAccessToken();
    const wsBase = base.replace(/^http/, "ws");
    return `${wsBase}/ws?token=${encodeURIComponent(token ?? "")}`;
  }

  private open(): void {
    const token = getAccessToken();
    if (!token || this.stopped) return;

    const gen = ++this.generation;

    try {
      this.ws = new WebSocket(this.wsUrl());
    } catch {
      this.scheduleReconnect();
      return;
    }

    const socket = this.ws;

    socket.onopen = () => {
      if (gen !== this.generation || this.stopped) return;
      this.backoffIndex = 0;
      this.onConnectionChange?.(true);
      this.startHeartbeat();
    };

    socket.onmessage = (event) => {
      if (gen !== this.generation) return;
      try {
        const frame = JSON.parse(event.data as string) as {
          type?: string;
          payload?: unknown;
        };
        if (frame.type === "pong") return;
        if (frame.type && this.onMessage) {
          this.onMessage(frame.type, frame.payload);
        }
      } catch {
        /* ignore malformed frames */
      }
    };

    socket.onclose = () => {
      if (gen !== this.generation) return;
      this.clearTimers();
      this.ws = null;
      this.onConnectionChange?.(false);
      this.scheduleReconnect();
    };

    socket.onerror = () => {
      if (gen !== this.generation) return;
      socket.close();
    };
  }

  private startHeartbeat(): void {
    this.clearHeartbeat();
    // Stay ahead of server idle timeout (54s) and proxies that drop quiet sockets.
    this.heartbeat = setInterval(() => {
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify({ type: "ping" }));
      }
    }, 30_000);
  }

  private scheduleReconnect(): void {
    if (this.stopped) return;
    if (this.reconnectTimer) return;
    const delay = this.backoffSteps[Math.min(this.backoffIndex, this.backoffSteps.length - 1)];
    this.backoffIndex = Math.min(this.backoffIndex + 1, this.backoffSteps.length - 1);
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      if (this.stopped) return;
      this.open();
    }, delay);
  }

  private clearHeartbeat(): void {
    if (this.heartbeat) clearInterval(this.heartbeat);
    this.heartbeat = null;
  }

  private clearTimers(): void {
    this.clearHeartbeat();
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  }
}

export function payloadToClipboardEntry(payload: unknown): import("./api").ClipboardEntry | null {
  if (!payload || typeof payload !== "object") return null;
  const p = payload as Record<string, unknown>;
  if (typeof p.entry_id !== "string") return null;
  const contentType = String(p.content_type ?? "text/plain");
  const content = typeof p.content === "string" ? p.content : "";
  const hasThumbnail = Boolean(p.has_thumbnail) || (contentType.startsWith("image/") && !content);
  if (!content && !hasThumbnail) return null;
  return {
    id: p.entry_id,
    content_type: contentType,
    content,
    has_thumbnail: hasThumbnail,
    source_device_id: String(p.source_device_id ?? ""),
    pinned: Boolean(p.pinned),
    created_at: String(p.created_at ?? new Date().toISOString()),
  };
}
