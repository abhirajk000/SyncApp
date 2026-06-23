const KEY_AUTO_SYNC = "syncbridge.clipboard.autoSync";
const KEY_AUTO_APPLY = "syncbridge.clipboard.autoApply";
const KEY_AUTO_SYNC_IMAGES = "syncbridge.clipboard.autoSyncImages";
const KEY_SHOW_NOTIFICATIONS = "syncbridge.clipboard.showNotifications";

function readBool(key: string, defaultValue: boolean): boolean {
  const raw = localStorage.getItem(key);
  if (raw === null) return defaultValue;
  return raw === "1" || raw === "true";
}

function writeBool(key: string, value: boolean): void {
  localStorage.setItem(key, value ? "1" : "0");
}

export interface ClipboardSettings {
  autoSyncClipboard: boolean;
  autoApplyRemoteClipboard: boolean;
  autoSyncImages: boolean;
  showClipboardNotifications: boolean;
}

export function loadClipboardSettings(): ClipboardSettings {
  return {
    autoSyncClipboard: readBool(KEY_AUTO_SYNC, true),
    autoApplyRemoteClipboard: readBool(KEY_AUTO_APPLY, false),
    autoSyncImages: readBool(KEY_AUTO_SYNC_IMAGES, true),
    showClipboardNotifications: readBool(KEY_SHOW_NOTIFICATIONS, true),
  };
}

export function saveClipboardSettings(patch: Partial<ClipboardSettings>): ClipboardSettings {
  const current = loadClipboardSettings();
  const next = { ...current, ...patch };
  writeBool(KEY_AUTO_SYNC, next.autoSyncClipboard);
  writeBool(KEY_AUTO_APPLY, next.autoApplyRemoteClipboard);
  writeBool(KEY_AUTO_SYNC_IMAGES, next.autoSyncImages);
  writeBool(KEY_SHOW_NOTIFICATIONS, next.showClipboardNotifications);
  window.dispatchEvent(new CustomEvent("syncbridge:clipboard-settings"));
  return next;
}
