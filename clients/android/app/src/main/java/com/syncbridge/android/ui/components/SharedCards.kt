package com.syncbridge.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.syncbridge.android.localsend.LocalPeer
import com.syncbridge.android.localsend.LocalTransferDirection
import com.syncbridge.android.localsend.LocalTransferPhase
import com.syncbridge.android.localsend.LocalTransferProgress
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.formatBytes
import kotlin.math.max

/** Shared DeviceCard — design/tokens.json spec */
@Composable
fun DeviceCard(
    name: String,
    platform: String,
    online: Boolean = true,
    connectionQuality: String = "Excellent",
    selected: Boolean = false,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val emoji = when (platform.lowercase()) {
        "macos" -> "💻"
        "android", "ios" -> "📱"
        "windows" -> "🖥️"
        else -> "📟"
    }
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(SyncTokens.RadiusCard))
            .background(AppSurfaces.card())
            .border(
                1.dp,
                if (selected) SyncTokens.Primary.copy(0.5f) else AppSurfaces.cardStroke(),
                RoundedCornerShape(SyncTokens.RadiusCard),
            )
            .clickable(onClick = onClick)
            .padding(SyncTokens.Space4),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space3),
    ) {
        Text("🟢", style = MaterialTheme.typography.titleMedium)
        Column(Modifier.weight(1f)) {
            Text(
                "$emoji $name",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                if (online) "Online · $connectionQuality" else "Offline",
                style = MaterialTheme.typography.bodySmall,
                color = if (online) SyncTokens.TextMuted else SyncTokens.Danger,
            )
        }
        if (selected) {
            CircularProgressIndicator(Modifier.size(SyncTokens.IconMd), strokeWidth = 2.dp, color = SyncTokens.Primary)
        }
    }
}

@Composable
fun DeviceCard(peer: LocalPeer, selected: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    DeviceCard(
        name = peer.name,
        platform = peer.platform,
        online = true,
        selected = selected,
        onClick = onClick,
        modifier = modifier,
    )
}

/** Shared TransferCard — design/tokens.json spec */
@Composable
fun TransferCard(
    progress: LocalTransferProgress,
    onCancel: () -> Unit,
    onOpenFolder: (() -> Unit)? = null,
    onSendMore: (() -> Unit)? = null,
    onDone: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val totalSize = progress.files.sumOf { it.size }
    val transferred = progress.files.sumOf { it.transferred }
    val pct = if (totalSize > 0) transferred.toFloat() / totalSize else 0f
    val remaining = max(0L, totalSize - transferred)
    val etaSec = if (progress.speedBytesPerSec > 0) remaining / progress.speedBytesPerSec else 0L

    AppCard(modifier = modifier) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
            Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space1)) {
                AppCardTitle(
                    if (progress.direction == LocalTransferDirection.Sending) "Sending to ${progress.peerName}"
                    else "Receiving from ${progress.peerName}",
                )
                Text(
                    phaseLabel(progress.phase),
                    style = MaterialTheme.typography.bodySmall,
                    color = phaseColor(progress.phase),
                    fontWeight = FontWeight.SemiBold,
                )
            }
            if (progress.phase == LocalTransferPhase.Transferring || progress.phase == LocalTransferPhase.Paused) {
                PremiumIconButton(onClick = onCancel, icon = Icons.Outlined.Close, contentDescription = "Cancel")
            }
        }
        Spacer(Modifier.height(SyncTokens.Space3))
        PremiumLinearProgress(progress = pct)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("${(pct * 100).toInt()}%", style = MaterialTheme.typography.bodySmall)
            Text(formatSpeed(progress.speedBytesPerSec), style = MaterialTheme.typography.bodySmall, color = SyncTokens.Primary)
        }
        Spacer(Modifier.height(SyncTokens.Space2))
        Text(
            "${formatBytes(transferred)} / ${formatBytes(totalSize)} · ${formatBytes(remaining)} left" +
                if (etaSec > 0) " · ~${etaSec}s" else "",
            style = MaterialTheme.typography.bodySmall,
            color = SyncTokens.TextMuted,
        )
        progress.files.forEach { file ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(file.name, style = MaterialTheme.typography.bodySmall, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                Text("${(file.percent * 100).toInt()}%", style = MaterialTheme.typography.bodySmall, color = SyncTokens.TextMuted)
            }
        }
        if (progress.phase == LocalTransferPhase.Completed) {
            Spacer(Modifier.height(SyncTokens.Space2))
            Text("Transfer Complete", color = SyncTokens.Success, fontWeight = FontWeight.Bold)
            Row(horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
                onOpenFolder?.let { GhostButton("Open Folder", it) }
                onSendMore?.let { GhostButton("Send More", it) }
                onDone?.let { PrimaryButton("Done", it, modifier = Modifier.weight(1f)) }
            }
        }
        progress.error?.let { Text(it, color = SyncTokens.Danger, style = MaterialTheme.typography.bodySmall) }
    }
}

@Composable
fun AppModal(
    title: String,
    message: String,
    confirmText: String,
    dismissText: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) = PremiumAppModal(title, message, confirmText, dismissText, onConfirm, onDismiss)

private fun phaseLabel(phase: LocalTransferPhase) = when (phase) {
    LocalTransferPhase.Idle -> "Idle"
    LocalTransferPhase.Connecting -> "Connecting"
    LocalTransferPhase.WaitingAccept -> "Waiting for receiver"
    LocalTransferPhase.Transferring -> "Transferring"
    LocalTransferPhase.Paused -> "Paused"
    LocalTransferPhase.Completed -> "Completed"
    LocalTransferPhase.Failed -> "Failed"
}

private fun phaseColor(phase: LocalTransferPhase): Color = when (phase) {
    LocalTransferPhase.Completed -> SyncTokens.Success
    LocalTransferPhase.Failed -> SyncTokens.Danger
    LocalTransferPhase.Paused -> SyncTokens.Warning
    else -> SyncTokens.TextMuted
}

private fun formatSpeed(bps: Long): String = when {
    bps >= 1_000_000 -> String.format("%.1f MB/s", bps / 1_000_000.0)
    bps >= 1_000 -> String.format("%.0f KB/s", bps / 1_000.0)
    bps > 0 -> "$bps B/s"
    else -> "—"
}
