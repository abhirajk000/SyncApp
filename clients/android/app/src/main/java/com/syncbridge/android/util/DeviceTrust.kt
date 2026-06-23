package com.syncbridge.android.util

import com.syncbridge.android.data.DeviceEntry
import java.time.Instant

private const val TRUSTED_RECENT_MS = 30L * 24 * 60 * 60 * 1000

/** True when the device is trusted and allowed to push clipboard to this client. */
fun isTrustedDevice(device: DeviceEntry, nowMs: Long = System.currentTimeMillis()): Boolean {
    val until = device.trustedUntil ?: return false
    return try {
        Instant.parse(until).toEpochMilli() > nowMs
    } catch (_: Exception) {
        false
    }
}

fun isTrustedDeviceId(deviceId: String, devices: List<DeviceEntry>): Boolean {
    if (deviceId.isBlank()) return false
    val device = devices.find { it.id == deviceId } ?: return false
    return isTrustedDevice(device)
}
