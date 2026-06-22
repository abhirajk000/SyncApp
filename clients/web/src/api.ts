const DEFAULT_SERVER = (
  import.meta.env.VITE_API_URL ?? "https://sync.abhiraj.xyz"
).replace(/\/$/, "");

export function getServerUrl(): string {
  return DEFAULT_SERVER;
}

const KEYS = {
  deviceId: "syncbridge.deviceId",
  accessToken: "syncbridge.accessToken",
  refreshToken: "syncbridge.refreshToken",
} as const;

/** Persist auth in localStorage so PIN isn't needed every browser visit (7-day tokens). */
const AUTH_STORE = localStorage;

function readAuth(key: string): string | null {
  return AUTH_STORE.getItem(key) ?? sessionStorage.getItem(key);
}

function writeAuth(key: string, value: string): void {
  AUTH_STORE.setItem(key, value);
  sessionStorage.setItem(key, value);
}

function removeAuth(key: string): void {
  AUTH_STORE.removeItem(key);
  sessionStorage.removeItem(key);
}

export interface AuthResponse {
  access_token: string;
  refresh_token: string;
  user_id: string;
  device_id: string;
  trusted_until: string;
}

export interface ClipboardEntry {
  id: string;
  content_type: string;
  content: string;
  has_thumbnail?: boolean;
  source_device_id: string;
  pinned: boolean;
  created_at: string;
  /** Client-side route label when known */
  transfer_route?: string;
}

export interface ClipboardHistoryResponse {
  entries: ClipboardEntry[];
  total: number;
}

export interface FileEntry {
  id: string;
  name: string;
  mime_type: string;
  total_size: number;
  status: string;
  is_pinned: boolean;
  created_at: string;
  transfer_mode?: string;
}

export interface FileListResponse {
  files: FileEntry[];
  total: number;
}

function ensureDeviceId(): string {
  let id = localStorage.getItem(KEYS.deviceId);
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem(KEYS.deviceId, id);
  }
  return id;
}

export function getAccessToken(): string | null {
  return readAuth(KEYS.accessToken);
}

export function clearSession(): void {
  removeAuth(KEYS.accessToken);
  removeAuth(KEYS.refreshToken);
}

export function isAuthenticated(): boolean {
  return getAccessToken() !== null;
}

export interface AuthStatusResponse {
  device_id: string;
  trusted_until: string | null;
  needs_pin: boolean;
}

/** Restore a saved session without re-entering PIN when still trusted. */
export async function restoreSession(): Promise<boolean> {
  if (!getAccessToken()) return false;
  try {
    const status = await fetchAuthStatus();
    if (status.needs_pin) {
      clearSession();
      return false;
    }
    return true;
  } catch {
    clearSession();
    return false;
  }
}

export async function fetchAuthStatus(): Promise<AuthStatusResponse> {
  return apiRequest<AuthStatusResponse>("/api/v1/auth/status");
}

async function apiRequest<T>(
  path: string,
  options: RequestInit = {},
  auth = true,
): Promise<T> {
  const base = getServerUrl().replace(/\/$/, "");
  const headers = new Headers(options.headers);

  if (options.body && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  if (auth) {
    const token = getAccessToken();
    if (!token) throw new Error("Not authenticated");
    headers.set("Authorization", `Bearer ${token}`);
  }

  const res = await fetch(`${base}${path}`, { ...options, headers });

  if (res.status === 401 && auth) {
    clearSession();
    throw new Error("Session expired — unlock again with PIN");
  }

  if (!res.ok) {
    let message = res.statusText;
    try {
      const err = await res.json();
      if (err.error) message = err.error;
    } catch {
      /* ignore */
    }
    throw new Error(message);
  }

  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

export async function unlock(pin: string): Promise<AuthResponse> {
  const body = {
    pin,
    device_id: ensureDeviceId(),
    device_name: "Web Browser",
    platform: "web",
  };

  const data = await apiRequest<AuthResponse>("/api/v1/auth/unlock", {
    method: "POST",
    body: JSON.stringify(body),
  }, false);

  writeAuth(KEYS.accessToken, data.access_token);
  writeAuth(KEYS.refreshToken, data.refresh_token);
  return data;
}

export async function fetchClipboardHistory(): Promise<ClipboardHistoryResponse> {
  return apiRequest<ClipboardHistoryResponse>("/api/v1/clipboard?limit=100");
}

export async function fetchCurrentClipboard(): Promise<ClipboardEntry> {
  return apiRequest<ClipboardEntry>("/api/v1/clipboard/current");
}

export async function fetchClipboardEntry(id: string): Promise<ClipboardEntry> {
  return apiRequest<ClipboardEntry>(`/api/v1/clipboard/${id}`);
}

export async function pinClipboard(id: string, pinned: boolean): Promise<void> {
  await apiRequest<void>(`/api/v1/clipboard/${id}/pin`, {
    method: "POST",
    body: JSON.stringify({ pinned }),
  });
}

export async function deleteClipboardEntry(entry: ClipboardEntry): Promise<void> {
  if (entry.pinned) {
    await pinClipboard(entry.id, false);
  }
  await apiRequest<void>(`/api/v1/clipboard/${entry.id}`, { method: "DELETE" });
}

export async function fetchFiles(): Promise<FileListResponse> {
  return apiRequest<FileListResponse>("/api/v1/files?limit=100");
}

export async function pinFile(id: string, pinned: boolean): Promise<void> {
  await apiRequest<void>(`/api/v1/files/${id}/pin`, {
    method: "POST",
    body: JSON.stringify({ pinned }),
  });
}

export async function deleteFileEntry(file: FileEntry): Promise<void> {
  if (file.is_pinned) {
    await pinFile(file.id, false);
  }
  await apiRequest<void>(`/api/v1/files/${file.id}`, { method: "DELETE" });
}

export async function syncClipboard(
  content: string,
  contentType = "text/plain",
): Promise<ClipboardEntry> {
  return apiRequest<ClipboardEntry>("/api/v1/clipboard", {
    method: "POST",
    body: JSON.stringify({ content_type: contentType, content }),
  });
}

export interface FileInitRequest {
  name: string;
  mime_type: string;
  total_size: number;
  chunk_size: number;
  file_hash: string;
  transfer_mode: string;
  force_relay: boolean;
}

export interface FileInitResponse {
  file_id: string;
  chunk_size: number;
  chunk_count: number;
  expires_at: string;
}

export async function initFileUpload(req: FileInitRequest): Promise<FileInitResponse> {
  return apiRequest<FileInitResponse>("/api/v1/files/init", {
    method: "POST",
    body: JSON.stringify(req),
  });
}

export async function completeFileUpload(fileId: string): Promise<FileEntry> {
  return apiRequest<FileEntry>(`/api/v1/files/${fileId}/complete`, {
    method: "POST",
    body: JSON.stringify({}),
  });
}

export interface DiagnosticsResponse {
  server_version: string;
  client_ip: string;
  local_peers: number;
  mdns_enabled: boolean;
  stun_urls: string[];
  turn_enabled: boolean;
  storage_backend: string;
  default_retention_minutes: number;
  retention_minutes: number;
}

export interface LocalPeer {
  device_id: string;
  addrs: string[];
  port: number;
  updated_at: string;
}

export interface LocalPeersResponse {
  peers: LocalPeer[];
}

export async function fetchDiagnostics(): Promise<DiagnosticsResponse> {
  return apiRequest<DiagnosticsResponse>("/api/v1/diagnostics");
}

export async function fetchLocalPeers(addrs = ""): Promise<LocalPeersResponse> {
  const q = addrs ? `?addrs=${encodeURIComponent(addrs)}` : "";
  return apiRequest<LocalPeersResponse>(`/api/v1/local/peers${q}`);
}

export async function advertiseLocalAddrs(addrs: string[], port = 0): Promise<void> {
  await apiRequest<void>("/api/v1/local/advertise", {
    method: "POST",
    body: JSON.stringify({ addrs, port }),
  });
}

export interface DeviceEntry {
  id: string;
  name: string;
  platform: string;
  fingerprint: string;
  trusted: boolean;
  last_seen_at?: string;
  created_at: string;
  is_current: boolean;
}

export interface DeviceListResponse {
  devices: DeviceEntry[];
  total: number;
}

export async function fetchDevices(): Promise<DeviceListResponse> {
  return apiRequest<DeviceListResponse>("/api/v1/devices");
}
