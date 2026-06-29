package com.syncbridge.android

import android.app.Application
import android.net.Uri
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.FileUploader
import com.syncbridge.android.localsend.LocalSendManager
import com.syncbridge.android.network.NetworkManager
import com.syncbridge.android.sync.ClipboardSettings
import com.syncbridge.android.sync.ClipboardSyncCoordinator

class SyncBridgeApp : Application() {

    lateinit var api: ApiClient
        private set

    lateinit var fileUploader: FileUploader
        private set

    lateinit var networkManager: NetworkManager
        private set

    lateinit var clipboardSync: ClipboardSyncCoordinator
        private set

    lateinit var clipboardSettings: ClipboardSettings
        private set

    lateinit var localSendManager: LocalSendManager
        private set

    var pendingShareText: String? = null
    var pendingShareUris: List<Uri>? = null

    override fun onCreate() {
        super.onCreate()
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        api = ApiClient(prefs)
        clipboardSettings = ClipboardSettings(prefs)
        networkManager = NetworkManager(this, api, prefs)
        fileUploader = FileUploader(this, api, networkManager)
        clipboardSync = ClipboardSyncCoordinator(this, api, clipboardSettings)
        localSendManager = LocalSendManager(this)
        localSendManager.start()
    }

    override fun onTerminate() {
        localSendManager.stop()
        super.onTerminate()
    }

    companion object {
        const val PREFS = "syncbridge"
    }
}
