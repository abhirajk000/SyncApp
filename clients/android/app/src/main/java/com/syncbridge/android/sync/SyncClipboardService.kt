package com.syncbridge.android.sync

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.syncbridge.android.MainActivity
import com.syncbridge.android.R
import com.syncbridge.android.SyncBridgeApp
import com.syncbridge.android.data.ClipboardEntry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class SyncClipboardService : Service() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private lateinit var repo: ClipboardRepository
    private var ws: WSClient? = null
    private var lastHash: String = ""
    private var suppressEcho = false

    private val clipListener = ClipboardManager.OnPrimaryClipChangedListener {
        if (suppressEcho) return@OnPrimaryClipChangedListener
        val (content, type) = repo.readPrimaryClip() ?: return@OnPrimaryClipChangedListener
        val hash = content.hashCode().toString()
        if (hash == lastHash) return@OnPrimaryClipChangedListener
        lastHash = hash
        scope.launch {
            try {
                repo.syncClipboard(type, content)
            } catch (_: Exception) {
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        val app = application as SyncBridgeApp
        repo = ClipboardRepository(this, app.api)
        createChannel()
        startForeground(NOTIFICATION_ID, buildNotification(getString(R.string.notification_sync_running)))

        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.addPrimaryClipChangedListener(clipListener)

        if (app.api.isAuthenticated) {
            ws = WSClient(app.api) { entry -> handleRemoteClipboard(entry) }.also { it.connect() }
        }
    }

    private fun handleRemoteClipboard(entry: ClipboardEntry) {
        suppressEcho = true
        repo.applyRemoteClip(entry.content)
        lastHash = entry.content.hashCode().toString()
        SyncEventBus.emitClipboard(entry)
        showClipboardNotification(entry.content)
        android.os.Handler(mainLooper).postDelayed({ suppressEcho = false }, 500)
    }

    override fun onDestroy() {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.removePrimaryClipChangedListener(clipListener)
        ws?.disconnect()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun showClipboardNotification(content: String) {
        val preview = if (content.length > 80) content.take(80) + "…" else content
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(CLIP_NOTIFICATION_ID, buildNotification("$preview"))
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
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
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
        const val CHANNEL_ID = "syncbridge_sync"
        const val NOTIFICATION_ID = 1
        const val CLIP_NOTIFICATION_ID = 2

        fun start(context: Context) {
            val intent = Intent(context, SyncClipboardService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SyncClipboardService::class.java))
        }
    }
}
