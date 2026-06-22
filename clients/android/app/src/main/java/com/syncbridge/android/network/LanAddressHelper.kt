package com.syncbridge.android.network

import java.net.Inet4Address
import java.net.NetworkInterface

object LanAddressHelper {
    fun localIpv4Addresses(): List<String> =
        NetworkInterface.getNetworkInterfaces().toList().flatMap { iface ->
            if (!iface.isUp || iface.isLoopback) return@flatMap emptyList()
            iface.inetAddresses.toList().mapNotNull { addr ->
                if (addr is Inet4Address && !addr.isLoopbackAddress) addr.hostAddress else null
            }
        }.distinct()
}
