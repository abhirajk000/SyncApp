package com.syncbridge.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.DeviceEntry
import com.syncbridge.android.ui.components.ContainerGroup
import com.syncbridge.android.ui.components.ContainerGroupItem
import com.syncbridge.android.ui.components.AppEmptyState
import com.syncbridge.android.ui.components.AppSkeleton
import com.syncbridge.android.ui.components.EmptyArt
import com.syncbridge.android.ui.components.AppModal
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.components.GhostButton
import com.syncbridge.android.ui.components.PremiumIconButton
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.relativeTime
import kotlinx.coroutines.launch
import java.time.Instant

@Composable
fun DevicesScreen(
    api: ApiClient,
    onBack: () -> Unit,
) {
    var devices by remember { mutableStateOf<List<DeviceEntry>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var removeTarget by remember { mutableStateOf<DeviceEntry?>(null) }
    val scope = rememberCoroutineScope()

    fun reload() {
        scope.launch {
            loading = true
            try {
                devices = api.fetchDevices()
            } catch (_: Exception) {
            } finally {
                loading = false
            }
        }
    }

    LaunchedEffect(Unit) { reload() }

    val current = devices.find { it.isCurrent }
    val others = devices.filter { !it.isCurrent }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(
                start = SyncTokens.Space4,
                end = SyncTokens.Space4,
                top = SyncTokens.Space4,
                bottom = SyncTokens.DockScrollPadding,
            ),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            PremiumIconButton(
                onClick = onBack,
                icon = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = "Back",
            )
            Text("Devices", style = MaterialTheme.typography.titleLarge)
        }

        if (loading) {
            AppSkeleton(rows = 4)
        } else {
            current?.let { device ->
                AppSectionTitle("This device")
                ContainerGroup {
                    TrustedDeviceContent(device = device)
                }
            }

            AppSectionTitle("Trusted devices")
            if (others.isEmpty()) {
                AppEmptyState(
                    title = "No other devices",
                    description = "Pair from your Mac or web settings to see them here.",
                    illustration = EmptyArt.Devices,
                )
            } else {
                ContainerGroup {
                    others.forEachIndexed { index, device ->
                        ContainerGroupItem(showDivider = index < others.lastIndex) {
                            TrustedDeviceContent(
                                device = device,
                                onTrust = if (!isTrusted(device)) {{ scope.launch { api.trustDevice(device.id); reload() } }} else null,
                                onRemove = { removeTarget = device },
                            )
                        }
                    }
                }
            }
        }
    }

    removeTarget?.let { device ->
        AppModal(
            title = "Remove device",
            message = "Remove \"${device.name}\" from your account?",
            confirmText = "Remove",
            dismissText = "Cancel",
            onConfirm = {
                scope.launch {
                    api.revokeDevice(device.id)
                    removeTarget = null
                    reload()
                }
            },
            onDismiss = { removeTarget = null },
        )
    }
}

@Composable
private fun TrustedDeviceContent(
    device: DeviceEntry,
    onTrust: (() -> Unit)? = null,
    onRemove: (() -> Unit)? = null,
) {
    Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space3), modifier = Modifier.fillMaxWidth()) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(if (device.online) SyncTokens.Teal else SyncTokens.SlateMuted),
                )
                Text(device.name, fontWeight = FontWeight.SemiBold)
            }
            Text(
                "${platformLabel(device.platform)}${if (device.isCurrent) " · This device" else ""}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                device.lastSeenAt?.let { relativeTime(it) } ?: "Never seen",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (onTrust != null || onRemove != null) {
                Row(horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
                    onTrust?.let { GhostButton("Trust", it) }
                    onRemove?.let { GhostButton("Remove", it) }
                }
            }
    }
}

private fun isTrusted(device: DeviceEntry): Boolean {
    val until = device.trustedUntil ?: return false
    return try {
        Instant.parse(until).isAfter(Instant.now())
    } catch (_: Exception) {
        false
    }
}

private fun platformLabel(platform: String): String = when (platform) {
    "macos" -> "macOS"
    "android" -> "Android"
    "ios" -> "iOS"
    "web" -> "Web"
    else -> platform.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
}
