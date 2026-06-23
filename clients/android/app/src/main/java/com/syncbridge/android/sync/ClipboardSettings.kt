package com.syncbridge.android.sync

import android.content.SharedPreferences

/** Client-side clipboard sync preferences (Settings → Clipboard). */
class ClipboardSettings(private val prefs: SharedPreferences) {

    var autoSyncClipboard: Boolean
        get() = prefs.getBoolean(KEY_AUTO_SYNC, true)
        set(value) = prefs.edit().putBoolean(KEY_AUTO_SYNC, value).apply()

    var autoApplyRemoteClipboard: Boolean
        get() = prefs.getBoolean(KEY_AUTO_APPLY, true)
        set(value) = prefs.edit().putBoolean(KEY_AUTO_APPLY, value).apply()

    var autoSyncImages: Boolean
        get() = prefs.getBoolean(KEY_AUTO_SYNC_IMAGES, true)
        set(value) = prefs.edit().putBoolean(KEY_AUTO_SYNC_IMAGES, value).apply()

    var showClipboardNotifications: Boolean
        get() = prefs.getBoolean(KEY_SHOW_NOTIFICATIONS, true)
        set(value) = prefs.edit().putBoolean(KEY_SHOW_NOTIFICATIONS, value).apply()

    companion object {
        private const val KEY_AUTO_SYNC = "clipboard_auto_sync"
        private const val KEY_AUTO_APPLY = "clipboard_auto_apply"
        private const val KEY_AUTO_SYNC_IMAGES = "clipboard_auto_sync_images"
        private const val KEY_SHOW_NOTIFICATIONS = "clipboard_show_notifications"
    }
}
