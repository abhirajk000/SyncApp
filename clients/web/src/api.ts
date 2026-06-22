const DEFAULT_SERVER =
  import.meta.env.VITE_API_URL ?? "http://localhost:8080";

/** Old API hosts — auto-migrate to DEFAULT_SERVER (same-origin via sync.abhiraj.xyz). */
const LEGACY_API_HOSTS = new Set([
  "api.abhiraj.xyz",
  "api.sync.abhiraj.xyz",
]);

function normalizeServerUrl(url: string): string {
  const trimmed = url.trim().replace(/\/$/, "");
  if (!trimmed) return DEFAULT_SERVER;
  try {
    const { hostname } = new URL(trimmed);
    if (LEGACY_API_HOSTS.has(hostname)) return DEFAULT_SERVER;
  } catch {
    return DEFAULT_SERVER;
  }
  return trimmed;
}

const KEYS = {
  serverUrl: "syncbridge.serverUrl",
  deviceId: "syncbridge.deviceId",
  accessToken: "syncbridge.accessToken",
  refreshToken: "syncbridge.refreshToken",
} as const;

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
  source_device_id: string;
  pinned: boolean;
  created_at: string;
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

export function getServerUrl(): string {
  const stored = sessionStorage.getItem(KEYS.serverUrl);
  if (!stored) return DEFAULT_SERVER;
  const normalized = normalizeServerUrl(stored);
  if (normalized !== stored) {
    sessionStorage.setItem(KEYS.serverUrl, normalized);
  }
  return normalized;
}

export function setServerUrl(url: string): void {
  sessionStorage.setItem(KEYS.serverUrl, normalizeServerUrl(url));
}

export function getAccessToken(): string | null {
  return sessionStorage.getItem(KEYS.accessToken);
}

export function clearSession(): void {
  sessionStorage.removeItem(KEYS.accessToken);
  sessionStorage.removeItem(KEYS.refreshToken);
}

export function isAuthenticated(): boolean {
  return getAccessToken() !== null;
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

  sessionStorage.setItem(KEYS.accessToken, data.access_token);
  sessionStorage.setItem(KEYS.refreshToken, data.refresh_token);
  return data;
}

export async function fetchClipboardHistory(): Promise<ClipboardHistoryResponse> {
  return apiRequest<ClipboardHistoryResponse>("/api/v1/clipboard?limit=100");
}

export async function fetchCurrentClipboard(): Promise<ClipboardEntry> {
  return apiRequest<ClipboardEntry>("/api/v1/clipboard/current");
}

export async function pinClipboard(id: string, pinned: boolean): Promise<void> {
  await apiRequest<void>(`/api/v1/clipboard/${id}/pin`, {
    method: "POST",
    body: JSON.stringify({ pinned }),
  });
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
