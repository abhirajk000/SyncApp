package com.syncbridge.android.localsend

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

class LocalSendDiscovery(
    private val context: Context,
    private val deviceId: String,
) {
    private val nsd = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val _peers = MutableStateFlow<List<LocalPeer>>(emptyList())
    val peers: StateFlow<List<LocalPeer>> = _peers.asStateFlow()

    private var registrationListener: NsdManager.RegistrationListener? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private var registeredPort = 0

    val friendlyName: String
        get() {
            val global = Settings.Global.getString(context.contentResolver, Settings.Global.DEVICE_NAME)
            if (!global.isNullOrBlank()) return global
            val model = Build.MODEL?.trim().orEmpty()
            return if (model.isNotBlank()) model else "Android Device"
        }

    fun start(port: Int) {
        registeredPort = port
        acquireMulticastLock()
        registerService(port)
        startDiscovery()
    }

    fun stop() {
        runCatching { discoveryListener?.let { nsd.stopServiceDiscovery(it) } }
        runCatching { registrationListener?.let { nsd.unregisterService(it) } }
        releaseMulticastLock()
        discoveryListener = null
        registrationListener = null
        _peers.value = emptyList()
    }

    private fun acquireMulticastLock() {
        val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        multicastLock = wifi.createMulticastLock("syncbridge-localsend").apply {
            setReferenceCounted(true)
            acquire()
        }
    }

    private fun releaseMulticastLock() {
        runCatching {
            multicastLock?.let {
                if (it.isHeld) it.release()
            }
        }
        multicastLock = null
    }

    private fun registerService(port: Int) {
        val serviceInfo = NsdServiceInfo().apply {
            serviceName = "SyncBridge-$deviceId"
            serviceType = LocalSendProtocol.SERVICE_TYPE
            setPort(port)
            setAttribute("id", deviceId)
            setAttribute("name", friendlyName)
            setAttribute("platform", "android")
        }
        val listener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(info: NsdServiceInfo) = Unit
            override fun onRegistrationFailed(info: NsdServiceInfo, code: Int) = Unit
            override fun onServiceUnregistered(info: NsdServiceInfo) = Unit
            override fun onUnregistrationFailed(info: NsdServiceInfo, code: Int) = Unit
        }
        registrationListener = listener
        nsd.registerService(serviceInfo, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    private fun startDiscovery() {
        val listener = object : NsdManager.DiscoveryListener {
            override fun onStartDiscoveryFailed(type: String, code: Int) = Unit
            override fun onStopDiscoveryFailed(type: String, code: Int) = Unit
            override fun onDiscoveryStarted(type: String) = Unit
            override fun onDiscoveryStopped(type: String) = Unit
            override fun onServiceFound(info: NsdServiceInfo) {
                if (info.serviceName.contains(deviceId)) return
                nsd.resolveService(
                    info,
                    object : NsdManager.ResolveListener {
                        override fun onResolveFailed(info: NsdServiceInfo, code: Int) = Unit
                        override fun onServiceResolved(resolved: NsdServiceInfo) {
                            val id = resolved.attributes["id"]?.decodeToString()?.trim().orEmpty()
                            if (id.isEmpty() || id == deviceId) return
                            val name = resolved.attributes["name"]?.decodeToString()?.trim()
                                ?: resolved.serviceName
                            val platform = resolved.attributes["platform"]?.decodeToString()?.trim() ?: "unknown"
                            val host = resolved.host?.hostAddress ?: return
                            val peer = LocalPeer(
                                id = id,
                                name = name,
                                platform = platform,
                                host = host,
                                port = resolved.port,
                            )
                            upsertPeer(peer)
                        }
                    },
                )
            }

            override fun onServiceLost(info: NsdServiceInfo) {
                _peers.value = _peers.value.filter { it.name != info.serviceName }
            }
        }
        discoveryListener = listener
        nsd.discoverServices(LocalSendProtocol.SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    private fun upsertPeer(peer: LocalPeer) {
        val current = _peers.value.toMutableList()
        val idx = current.indexOfFirst { it.id == peer.id }
        if (idx >= 0) current[idx] = peer else current.add(peer)
        _peers.value = current.sortedBy { it.name.lowercase() }
    }

    companion object {
        fun deviceId(context: Context): String {
            val prefs = context.getSharedPreferences("syncbridge", Context.MODE_PRIVATE)
            val key = "local_send_device_id"
            prefs.getString(key, null)?.let { return it }
            val id = UUID.randomUUID().toString()
            prefs.edit().putString(key, id).apply()
            return id
        }
    }
}
