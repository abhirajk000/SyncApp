// ClipboardSettings.swift — Settings → Clipboard toggles

import Foundation

enum ClipboardSettings {
    private static let autoSyncKey = "com.syncbridge.clipboard.autoSync"
    private static let autoApplyKey = "com.syncbridge.clipboard.autoApply"
    private static let autoSyncImagesKey = "com.syncbridge.clipboard.autoSyncImages"
    private static let showNotificationsKey = "com.syncbridge.clipboard.showNotifications"

    static var autoSyncClipboard: Bool {
        get { UserDefaults.standard.object(forKey: autoSyncKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: autoSyncKey) }
    }

    static var autoApplyRemoteClipboard: Bool {
        get { UserDefaults.standard.object(forKey: autoApplyKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: autoApplyKey) }
    }

    static var autoSyncImages: Bool {
        get { UserDefaults.standard.object(forKey: autoSyncImagesKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: autoSyncImagesKey) }
    }

    static var showClipboardNotifications: Bool {
        get { UserDefaults.standard.object(forKey: showNotificationsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: showNotificationsKey) }
    }
}
