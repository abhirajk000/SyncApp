package com.syncbridge.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.syncbridge.android.R
import com.syncbridge.android.network.NetworkSnapshot
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.relativeTime

/** Glass top app bar — shared shell (Phase 2). */
@Composable
fun AppTopBar(
    connected: Boolean,
    refreshing: Boolean,
    onRefresh: () -> Unit,
    network: NetworkSnapshot?,
    modifier: Modifier = Modifier,
) {
    var showConnMenu by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(AppSurfaces.card()),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(SyncTokens.HeaderHeight)
                .padding(horizontal = SyncTokens.Space4),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space3),
            ) {
                androidx.compose.foundation.Image(
                    painter = painterResource(R.drawable.ic_launcher_foreground),
                    contentDescription = null,
                    modifier = Modifier.size(28.dp),
                )
                Text("SyncBridge", style = MaterialTheme.typography.titleLarge)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                PremiumIconButton(
                    onClick = { if (!refreshing) onRefresh() },
                    icon = Icons.Outlined.Refresh,
                    contentDescription = "Refresh sync",
                    tint = if (refreshing) SyncTokens.SlateMuted else SyncTokens.Teal,
                    modifier = if (refreshing) Modifier.rotate(360f) else Modifier,
                )
                Box(Modifier.padding(end = SyncTokens.Space2)) {
                    ConnectionChip(connected = connected, onClick = { showConnMenu = true })
                    network?.let { net ->
                        DropdownMenu(expanded = showConnMenu, onDismissRequest = { showConnMenu = false }) {
                            DropdownMenuItem(
                                text = { Text("Server: ${if (net.diagnostics != null) "Online" else "—"}") },
                                onClick = { showConnMenu = false },
                                enabled = false,
                            )
                            DropdownMenuItem(
                                text = { Text("Peers: ${net.peers.size}") },
                                onClick = { showConnMenu = false },
                                enabled = false,
                            )
                            DropdownMenuItem(
                                text = { Text("Transfer: ${net.currentTransferMode}") },
                                onClick = { showConnMenu = false },
                                enabled = false,
                            )
                            DropdownMenuItem(
                                text = { Text("Latency: ${net.latencyMs?.let { "${it} ms" } ?: "—"}") },
                                onClick = { showConnMenu = false },
                                enabled = false,
                            )
                            DropdownMenuItem(
                                text = { Text("Last sync: ${net.lastSyncAt?.let { relativeTime(it) } ?: "—"}") },
                                onClick = { showConnMenu = false },
                                enabled = false,
                            )
                        }
                    }
                }
            }
        }
        HorizontalDivider(color = SyncTokens.CardBorder)
    }
}
