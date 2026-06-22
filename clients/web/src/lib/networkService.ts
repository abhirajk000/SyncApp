/** Central network state, discovery, routing, and diagnostics logging. */

import {
  advertiseLocalAddrs,
  fetchDiagnostics,
  fetchDevices,
  fetchLocalPeers,
  type DeviceEntry,
  type DiagnosticsResponse,
  type LocalPeer,
} from "../api";
import {
  type TransferRoute,
  systemTransferModeLabel,
  peerQueryAddrs,
} from "./network";
import { resolveFileUploadRoute, type FileRouteContext } from "./fileRouting";

export interface SignalPeerEvent {
  device_id: string;
  addrs: string[];
  port?: number;
  at: string;
}

export interface TransferLogEntry {
  id: string;
  at: string;
  name: string;
  method: TransferRoute;
  fallbackReason?: string;
  bytesPerSec?: number;
  peerDeviceId?: string;
}

export interface EnrichedPeer {
  device_id: string;
  addrs: string[];
  port: number;
  updated_at: string;
  name: string;
  platform: string;
  connectionType: TransferRoute;
  onLan: boolean;
}

export interface NetworkSnapshot {
  diagnostics: DiagnosticsResponse | null;
  wsConnected: boolean;
  peers: LocalPeer[];
  devices: DeviceEntry[];
  enrichedPeers: EnrichedPeer[];
  lastSignalTime: string | null;
  lastSignalPeer: SignalPeerEvent | null;
  nearbyAlert: SignalPeerEvent | null;
  currentTransferMode: string;
  lastSyncAt: string | null;
  latencyMs: number | null;
  transferLogs: TransferLogEntry[];
  loading: boolean;
  error: string | null;
}

const ADVERTISE_MS = 60_000;
const REFRESH_MS = 15_000;
const MAX_LOGS = 50;

type Listener = () => void;

function platformLabel(platform: string): string {
  switch (platform) {
    case "macos": return "Mac";
    case "android": return "Android";
    case "ios": return "iPhone";
    case "web": return "Web";
    default: return platform;
  }
}

function enrichPeers(peers: LocalPeer[], devices: DeviceEntry[]): EnrichedPeer[] {
  const byId = new Map(devices.map((d) => [d.id, d]));
  return peers.map((p) => {
    const dev = byId.get(p.device_id);
    return {
      device_id: p.device_id,
      addrs: p.addrs,
      port: p.port,
      updated_at: p.updated_at,
      name: dev?.name ?? "Unknown device",
      platform: dev?.platform ?? "unknown",
      connectionType: "direct_lan" as TransferRoute,
      onLan: true,
    };
  });
}

function connectedDevices(devices: DeviceEntry[], peers: LocalPeer[]): EnrichedPeer[] {
  const peerIds = new Set(peers.map((p) => p.device_id));
  return devices
    .filter((d) => !d.is_current)
    .map((d) => ({
      device_id: d.id,
      addrs: [],
      port: 0,
      updated_at: d.last_seen_at ?? d.created_at,
      name: d.name,
      platform: d.platform,
      connectionType: peerIds.has(d.id) ? ("direct_lan" as TransferRoute) : ("cloud" as TransferRoute),
      onLan: peerIds.has(d.id),
    }));
}

class NetworkService {
  private listeners = new Set<Listener>();
  private advertiseTimer: ReturnType<typeof setInterval> | null = null;
  private refreshTimer: ReturnType<typeof setInterval> | null = null;
  private clientIp = "";
  /** Peers we have already announced this session — avoids toast spam. */
  private knownPeerIds = new Set<string>();

  private state: NetworkSnapshot = {
    diagnostics: null,
    wsConnected: false,
    peers: [],
    devices: [],
    enrichedPeers: [],
    lastSignalTime: null,
    lastSignalPeer: null,
    nearbyAlert: null,
    currentTransferMode: "Automatic",
    lastSyncAt: null,
    latencyMs: null,
    transferLogs: [],
    loading: false,
    error: null,
  };

  getSnapshot = (): NetworkSnapshot => this.state;

  subscribe = (listener: Listener): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  private emit() {
    for (const l of this.listeners) l();
  }

  private patch(partial: Partial<NetworkSnapshot>) {
    this.state = { ...this.state, ...partial };
    this.emit();
  }

  setWsConnected(connected: boolean) {
    this.patch({
      wsConnected: connected,
      currentTransferMode: systemTransferModeLabel(connected),
    });
  }

  markSync() {
    this.patch({ lastSyncAt: new Date().toISOString() });
  }

  /** Handle signal.peer; returns true only the first time we see a device (for optional toast). */
  handleSignalPeer(payload: unknown): boolean {
    if (!payload || typeof payload !== "object") return false;
    const p = payload as Record<string, unknown>;
    const deviceId = String(p.device_id ?? "");
    if (!deviceId) return false;
    const addrs = Array.isArray(p.addrs) ? p.addrs.map(String) : [];
    const port = typeof p.port === "number" ? p.port : 0;
    const event: SignalPeerEvent = {
      device_id: deviceId,
      addrs,
      port,
      at: new Date().toISOString(),
    };

    const isNew = !this.knownPeerIds.has(deviceId);
    if (isNew) this.knownPeerIds.add(deviceId);

    this.patch({
      lastSignalTime: event.at,
      lastSignalPeer: event,
      nearbyAlert: isNew ? event : this.state.nearbyAlert,
    });

    // Do NOT refresh/advertise here — that re-triggers signal.peer storms.
    return isNew;
  }

  dismissNearbyAlert() {
    this.patch({ nearbyAlert: null });
  }

  /** Automatic file routing — clipboard always uses relay separately. */
  resolveUploadRoute(ctx: FileRouteContext): {
    transferMode: "relay" | "webrtc";
    route: TransferRoute;
    fallbackReason?: string;
  } {
    const resolved = resolveFileUploadRoute(ctx);
    return {
      transferMode: resolved.transferMode,
      route: resolved.route === "webrtc" ? "webrtc" : "cloud",
      fallbackReason: resolved.fallbackReason,
    };
  }

  logTransfer(entry: Omit<TransferLogEntry, "id" | "at">) {
    const log: TransferLogEntry = {
      ...entry,
      id: crypto.randomUUID(),
      at: new Date().toISOString(),
    };
    const transferLogs = [log, ...this.state.transferLogs].slice(0, MAX_LOGS);
    this.patch({ transferLogs });
  }

  async refresh(): Promise<void> {
    this.patch({ loading: true, error: null });
    const t0 = performance.now();
    try {
      const diagnostics = await fetchDiagnostics();
      this.clientIp = diagnostics.client_ip;
      const addrs = peerQueryAddrs(diagnostics.client_ip);
      if (addrs) {
        try {
          await advertiseLocalAddrs([addrs], 0);
        } catch {
          /* web cannot bind LAN port */
        }
      }
      const [peerData, deviceData] = await Promise.all([
        fetchLocalPeers(addrs),
        fetchDevices().catch(() => ({ devices: [] as DeviceEntry[], total: 0 })),
      ]);
      const peers = peerData.peers;
      const devices = deviceData.devices;
      const enrichedPeers = enrichPeers(peers, devices);
      const latencyMs = Math.round(performance.now() - t0);
      this.patch({
        diagnostics,
        peers,
        devices,
        enrichedPeers,
        latencyMs,
        loading: false,
        currentTransferMode: systemTransferModeLabel(this.state.wsConnected),
      });
    } catch (e) {
      this.patch({
        loading: false,
        error: e instanceof Error ? e.message : "Network refresh failed",
      });
    }
  }

  start() {
    void this.refresh();
    if (this.advertiseTimer) clearInterval(this.advertiseTimer);
    if (this.refreshTimer) clearInterval(this.refreshTimer);
    this.advertiseTimer = setInterval(() => {
      const addrs = peerQueryAddrs(this.clientIp);
      if (addrs) void advertiseLocalAddrs([addrs], 0).catch(() => undefined);
    }, ADVERTISE_MS);
    this.refreshTimer = setInterval(() => void this.refresh(), REFRESH_MS);
  }

  stop() {
    if (this.advertiseTimer) clearInterval(this.advertiseTimer);
    if (this.refreshTimer) clearInterval(this.refreshTimer);
    this.advertiseTimer = null;
    this.refreshTimer = null;
    this.knownPeerIds.clear();
    this.patch({
      diagnostics: null,
      peers: [],
      devices: [],
      enrichedPeers: [],
      nearbyAlert: null,
      wsConnected: false,
    });
  }
}

export const networkService = new NetworkService();
export { platformLabel, connectedDevices, enrichPeers };
