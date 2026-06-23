package com.syncbridge.android.sync

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.syncbridge.android.MainActivity
import com.syncbridge.android.R
import com.syncbridge.android.SyncBridgeApp
import com.syncbridge.android.data.ClipboardEntry

class SyncClipboardService : Service() {

    private lateinit var coordinator: ClipboardSyncCoordinator
    private var ws: WSClient? = null
    private var screenshotWatcher: ScreenshotWatcher? = null

    private val clipListener = ClipboardManager.OnPrimaryClipChangedListener {
        coordinator.onLocalClipboardChanged()
    }

    override fun onCreate() {
        super.onCreate()
        val app = application as SyncBridgeApp
        coordinator = app.clipboardSync
        createChannel()
        promoteToForeground()

        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.addPrimaryClipChangedListener(clipListener)

        if (app.api.isAuthenticated) {
            app.networkManager.start()
            ws = WSClient(app.api, app.networkManager) { entry ->
                handleRemoteClipboard(entry)
            }.also { it.connect() }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureScreenshotWatcher()
        return START_STICKY
    }

    private fun ensureScreenshotWatcher() {
        if (!hasScreenshotAccess()) {
            Log.w(TAG, "screenshot watcher waiting for Photos permission")
            return
        }
        if (screenshotWatcher == null) {
            screenshotWatcher = ScreenshotWatcher(this) { uri ->
                coordinator.onScreenshotUri(uri)
            }.also { it.start() }
        }
    }

    private fun handleRemoteClipboard(entry: ClipboardEntry) {
        val app = application as SyncBridgeApp
        val localId = app.api.ensureDeviceId()
        coordinator.handleRemoteClipboard(entry)

        if (entry.sourceDeviceId.isNotBlank() && entry.sourceDeviceId == localId) return
        if (!coordinator.settings.showClipboardNotifications) return
        val preview = if (entry.contentType.startsWith("image/")) {
            "Image received"
        } else {
            val content = entry.content
            if (content.length > 80) content.take(80) + "…" else content
        }
        showClipboardNotification(preview)
    }

    override fun onDestroy() {
        screenshotWatcher?.stop()
        screenshotWatcher = null
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.removePrimaryClipChangedListener(clipListener)
        ws?.disconnect()
        (application as SyncBridgeApp).networkManager.stop()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun hasScreenshotAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_MEDIA_IMAGES) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    private fun showClipboardNotification(content: String) {
        val preview = if (content.length > 80) content.take(80) + "…" else content
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(CLIP_NOTIFICATION_ID, buildNotification(preview))
    }

    private fun buildNotification(text: String): Notification {
        val launch = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_stat_sync)
            .setContentIntent(pending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun promoteToForeground() {
        try {
            startForeground(NOTIFICATION_ID, buildNotification(getString(R.string.notification_sync_running)))
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
            stopSelf()
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                getString(R.string.sync_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = getString(R.string.sync_channel_desc)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    companion object {
        private const val TAG = "SyncClipboardService"
        const val CHANNEL_ID = "syncbridge_sync"
        const val NOTIFICATION_ID = 1
        const val CLIP_NOTIFICATION_ID = 2

        fun start(context: Context) {
            try {
                val intent = Intent(context, SyncClipboardService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Unable to start sync service", e)
            }
        }

        fun restart(context: Context) {
            stop(context)
            start(context)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SyncClipboardService::class.java))
        }
    }
}
