package com.syncbridge.android.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.material3.TextButton
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.syncbridge.android.network.NetworkManager
import com.syncbridge.android.network.NetworkPreferences
import com.syncbridge.android.network.TransferRoute
import com.syncbridge.android.ui.components.AppCard
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.components.GlassListRow
import com.syncbridge.android.ui.components.TransferBadge
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.relativeTime
import kotlinx.coroutines.launch

@Composable
fun NetworkScreen(
    networkManager: NetworkManager,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("syncbridge", android.content.Context.MODE_PRIVATE) }
    val net by networkManager.state.collectAsState()
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(SyncTokens.Space4),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
            }
            IconButton(onClick = { scope.launch { networkManager.refreshOncePublic() } }) {
                Icon(Icons.Default.Refresh, contentDescription = "Refresh")
            }
        }

        Text("Network", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text(
            "Connection topology and transfer routing.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = SyncTokens.Space4),
        )

        net.nearbyAlert?.let { alert ->
            AppCard(modifier = Modifier.padding(bottom = SyncTokens.Space4)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Nearby device available", fontWeight = FontWeight.Bold)
                        Text(
                            "Device ${alert.deviceId.take(8)}… on ${alert.addrs.joinToString(", ")}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    TextButton(onClick = { networkManager.dismissNearbyAlert() }) {
                        Text("Dismiss")
                    }
                }
            }
        }

        if (net.error != null) {
            Text(net.error!!, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(bottom = SyncTokens.Space2))
        }

        LazyColumn(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4)) {
            item {
                AppSectionTitle("Connection status")
                AppCard {
                    StatusRow("Server", if (net.diagnostics != null) "Online" else if (net.loading) "Checking…" else "Unreachable")
                    net.diagnostics?.serverVersion?.takeIf { it.isNotBlank() }?.let { v ->
                        Text("v$v", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    StatusRow("WebSocket", if (net.wsConnected) "Connected" else "Disconnected")
                    StatusRow("File routing", "Automatic")
                    StatusRow("Clipboard", "Cloud relay (always)")
                    StatusRow("LAN peer count", net.peers.size.toString())
                    StatusRow("mDNS", if (net.diagnostics?.mdnsEnabled == true) "Enabled" else "Disabled")
                    StatusRow("Your IP", net.diagnostics?.clientIp?.ifBlank { "—" } ?: "—", mono = true)
                    StatusRow("Last signal", net.lastSignalTime?.let { relativeTime(it) } ?: "—")
                }
            }

            item {
                AppSectionTitle("Connected devices")
                if (net.devices.filter { !it.isCurrent }.isEmpty()) {
                    AppCard {
                        Text("No other devices registered.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                } else {
                    net.devices.filter { !it.isCurrent }.forEach { dev ->
                        val onLan = net.peers.any { it.deviceId == dev.id }
                        GlassListRow {
                            Column {
                                Text(dev.name, fontWeight = FontWeight.SemiBold)
                                Text(
                                    "${NetworkManager.platformLabel(dev.platform)} · ${relativeTime(dev.lastSeenAt ?: dev.createdAt)}",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                                TransferBadge(transferMode = "relay")
                            }
                        }
                    }
                }
            }

            item {
                AppSectionTitle("Routing policy")
                AppCard {
                    Text(
                        "Clipboard text and images always use cloud relay. " +
                            "Files under 100 MB use relay. Larger files, folders, and multi-file uploads " +
                            "attempt WebRTC with automatic relay fallback.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            item { AppSectionTitle("Nearby devices") }

            if (net.enrichedPeers.isEmpty()) {
                item {
                    AppCard {
                        Text(
                            "No devices on the same network right now.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            } else {
                items(net.enrichedPeers, key = { it.deviceId }) { peer ->
                    GlassListRow {
                        Column {
                            Text(peer.name, fontWeight = FontWeight.SemiBold)
                            Text(
                                "${NetworkManager.platformLabel(peer.platform)} · ${peer.addrs.joinToString(", ")}",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            if (peer.updatedAt.isNotBlank()) {
                                Text(
                                    "Last seen ${relativeTime(peer.updatedAt)} · Direct LAN",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
            }

            if (net.transferLogs.isNotEmpty()) {
                item { AppSectionTitle("Transfer diagnostics") }
                items(net.transferLogs, key = { it.id }) { log ->
                    AppCard {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Text(log.name, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodySmall)
                            TransferBadge(transferMode = when (log.method) {
                                TransferRoute.WebRtc -> "webrtc"
                                else -> "relay"
                            })
                        }
                        log.fallbackReason?.let {
                            Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        log.bytesPerSec?.let { bps ->
                            Text("${bps / 1024} KB/s", style = MaterialTheme.typography.labelSmall)
                        }
                        log.peerDeviceId?.let {
                            Text("Peer: ${it.take(8)}…", style = MaterialTheme.typography.labelSmall, fontFamily = FontFamily.Monospace)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun StatusRow(label: String, value: String, mono: Boolean = false) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = SyncTokens.Space1),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(
            value,
            fontFamily = if (mono) FontFamily.Monospace else FontFamily.Default,
            style = MaterialTheme.typography.bodySmall,
        )
    }
}
