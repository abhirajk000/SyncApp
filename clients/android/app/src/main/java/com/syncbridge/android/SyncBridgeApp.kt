package com.syncbridge.android

import android.app.Application
import android.net.Uri
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.FileUploader
import com.syncbridge.android.network.NetworkManager

class SyncBridgeApp : Application() {

    lateinit var api: ApiClient
        private set

    lateinit var fileUploader: FileUploader
        private set

    lateinit var networkManager: NetworkManager
        private set

    var pendingShareText: String? = null
    var pendingShareUris: List<Uri>? = null

    override fun onCreate() {
        super.onCreate()
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        api = ApiClient(prefs)
        networkManager = NetworkManager(this, api, prefs)
        fileUploader = FileUploader(this, api, networkManager)
    }

    companion object {
        const val PREFS = "syncbridge"
    }
}
