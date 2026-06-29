package com.syncbridge.android.ui.screens

import android.app.DownloadManager
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Wifi
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import com.syncbridge.android.ui.components.PremiumIconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.syncbridge.android.localsend.IncomingOffer
import com.syncbridge.android.localsend.LocalPeer
import com.syncbridge.android.localsend.LocalSendManager
import com.syncbridge.android.localsend.LocalTransferPhase
import com.syncbridge.android.ui.components.AppCard
import com.syncbridge.android.ui.components.AppCardDesc
import com.syncbridge.android.ui.components.AppCardTitle
import com.syncbridge.android.ui.components.AppEmptyState
import com.syncbridge.android.ui.components.AppModal
import com.syncbridge.android.ui.components.AppSurfaces
import com.syncbridge.android.ui.components.DeviceCard
import com.syncbridge.android.ui.components.EmptyArt
import com.syncbridge.android.ui.components.GhostButton
import com.syncbridge.android.ui.components.PrimaryButton
import com.syncbridge.android.ui.components.TransferCard
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.formatBytes

private enum class LocalSendStep {
    Intro, Nearby, ChooseDevice, ChooseFiles, Preview, Transfer, Success,
}

private val STEP_LABELS = listOf(
    "Send", "Nearby", "Device", "Files", "Preview", "Transfer", "Success",
)

private data class PendingLocalFile(val uri: Uri, val name: String, val size: Long)

@Composable
fun LocalSendScreen(
    manager: LocalSendManager,
    onBack: (() -> Unit)? = null,
) {
    val peers by manager.peers.collectAsState()
    val progress by manager.progress.collectAsState()
    val incoming by manager.incomingOffer.collectAsState()
    val context = LocalContext.current

    var stepIndex by remember { mutableIntStateOf(0) }
    var selectedPeer by remember { mutableStateOf<LocalPeer?>(null) }
    var pendingFiles by remember { mutableStateOf<List<PendingLocalFile>>(emptyList()) }

    val step = LocalSendStep.entries[stepIndex]

    LaunchedEffect(progress?.phase) {
        when (progress?.phase) {
            LocalTransferPhase.Transferring,
            LocalTransferPhase.Connecting,
            LocalTransferPhase.WaitingAccept,
            -> if (stepIndex < LocalSendStep.Transfer.ordinal) {
                stepIndex = LocalSendStep.Transfer.ordinal
            }
            LocalTransferPhase.Completed -> stepIndex = LocalSendStep.Success.ordinal
            else -> Unit
        }
    }

    val filePicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        uris.forEach { uri ->
            try {
                context.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: Exception) { }
        }
        if (uris.isNotEmpty()) {
            pendingFiles = resolveFiles(context, uris)
            stepIndex = LocalSendStep.Preview.ordinal
        }
    }

    incoming?.let { offer -> IncomingModal(offer, manager) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = SyncTokens.Space4),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = SyncTokens.Space4, bottom = SyncTokens.Space2),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2),
        ) {
            if (onBack != null || stepIndex > 0) {
                PremiumIconButton(
                    onClick = {
                        if (stepIndex == 0) onBack?.invoke() else stepIndex = (stepIndex - 1).coerceAtLeast(0)
                    },
                    icon = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                )
            }
            Text("Local Send", style = MaterialTheme.typography.titleLarge)
        }

        LocalSendStepper(stepIndex)

        AnimatedContent(
            targetState = step,
            transitionSpec = {
                (fadeIn(tween(350)) + slideInHorizontally { it / 4 })
                    .togetherWith(fadeOut(tween(250)) + slideOutHorizontally { -it / 4 })
            },
            label = "localSendStep",
            modifier = Modifier.weight(1f),
        ) { current ->
            when (current) {
                LocalSendStep.Intro -> IntroStep(onStart = { stepIndex = LocalSendStep.Nearby.ordinal })
                LocalSendStep.Nearby -> NearbyStep(
                    peerCount = peers.size,
                    onContinue = { stepIndex = LocalSendStep.ChooseDevice.ordinal },
                )
                LocalSendStep.ChooseDevice -> ChooseDeviceStep(
                    peers = peers,
                    selected = selectedPeer,
                    onSelect = { selectedPeer = it },
                    onContinue = {
                        if (selectedPeer != null) stepIndex = LocalSendStep.ChooseFiles.ordinal
                    },
                )
                LocalSendStep.ChooseFiles -> ChooseFilesStep(
                    onPick = { filePicker.launch(arrayOf("*/*")) },
                )
                LocalSendStep.Preview -> PreviewStep(
                    files = pendingFiles,
                    peer = selectedPeer,
                    onSend = {
                        val peer = selectedPeer
                        if (peer != null && pendingFiles.isNotEmpty()) {
                            manager.sendToPeer(peer, pendingFiles.map { it.uri })
                            stepIndex = LocalSendStep.Transfer.ordinal
                        }
                    },
                )
                LocalSendStep.Transfer -> {
                    val p = progress
                    if (p != null) {
                        TransferStep(
                            progress = p,
                            manager = manager,
                            onPickMore = { filePicker.launch(arrayOf("*/*")) },
                        )
                    } else {
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text("Starting transfer…", color = SyncTokens.TextMuted)
                        }
                    }
                }
                LocalSendStep.Success -> SuccessStep(
                    peerName = selectedPeer?.name ?: progress?.peerName ?: "device",
                    onSendMore = {
                        manager.clearCompletedTransfer()
                        pendingFiles = emptyList()
                        selectedPeer = null
                        stepIndex = LocalSendStep.Intro.ordinal
                    },
                    onDone = {
                        manager.clearCompletedTransfer()
                        onBack?.invoke()
                    },
                )
            }
        }
    }
}

@Composable
private fun LocalSendStepper(activeIndex: Int) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = SyncTokens.Space3),
        horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space1),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        STEP_LABELS.forEachIndexed { i, label ->
            val active = i == activeIndex
            val done = i < activeIndex
            Box(
                modifier = Modifier
                    .size(if (active) 10.dp else 8.dp)
                    .clip(CircleShape)
                    .background(
                        when {
                            done -> SyncTokens.Success
                            active -> SyncTokens.Primary
                            else -> SyncTokens.CardBorder
                        },
                    ),
            )
            if (i < STEP_LABELS.lastIndex) {
                Box(
                    Modifier
                        .weight(1f)
                        .height(2.dp)
                        .background(if (done) SyncTokens.Success.copy(0.5f) else SyncTokens.CardBorder),
                )
            }
        }
    }
}

@Composable
private fun IntroStep(onStart: () -> Unit) {
    LazyColumn(contentPadding = PaddingValues(bottom = SyncTokens.DockScrollPadding)) {
        item {
            AppCard(hero = true) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space3)) {
                    Box(
                        modifier = Modifier
                            .size(SyncTokens.Icon2xl)
                            .clip(CircleShape)
                            .background(Brush.linearGradient(listOf(SyncTokens.Indigo, SyncTokens.Violet))),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(Icons.Outlined.Wifi, null, tint = Color.White)
                    }
                    Column {
                        AppCardTitle("Direct Wi‑Fi transfer")
                        AppCardDesc("Send files device-to-device on the same network. No cloud.")
                    }
                }
                Spacer(Modifier.height(SyncTokens.Space4))
                PrimaryButton(text = "Start", onClick = onStart)
            }
        }
    }
}

@Composable
private fun NearbyStep(peerCount: Int, onContinue: () -> Unit) {
    val pulse = rememberInfiniteTransition(label = "scan")
    val scale by pulse.animateFloat(
        initialValue = 0.92f,
        targetValue = 1.08f,
        animationSpec = infiniteRepeatable(tween(1400), RepeatMode.Reverse),
        label = "scale",
    )
    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
        contentPadding = PaddingValues(bottom = SyncTokens.DockScrollPadding),
    ) {
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(140.dp),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    Modifier
                        .size(100.dp)
                        .scale(scale)
                        .clip(CircleShape)
                        .border(2.dp, SyncTokens.Primary.copy(0.35f), CircleShape),
                )
                Icon(Icons.Outlined.Wifi, null, tint = SyncTokens.Primary, modifier = Modifier.size(32.dp))
            }
        }
        item {
            if (peerCount == 0) {
                AppEmptyState(
                    title = "Looking for devices…",
                    description = "Open Local Send on another device on the same Wi‑Fi.",
                    illustration = EmptyArt.Devices,
                )
            } else {
                Text(
                    "$peerCount device${if (peerCount == 1) "" else "s"} nearby",
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    color = SyncTokens.TextMuted,
                )
                PrimaryButton(text = "Continue", onClick = onContinue)
            }
        }
    }
}

@Composable
private fun ChooseDeviceStep(
    peers: List<LocalPeer>,
    selected: LocalPeer?,
    onSelect: (LocalPeer) -> Unit,
    onContinue: () -> Unit,
) {
    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space3),
        contentPadding = PaddingValues(bottom = SyncTokens.DockScrollPadding),
    ) {
        items(peers, key = { it.id }) { peer ->
            DeviceCard(
                peer = peer,
                selected = selected?.id == peer.id,
                onClick = { onSelect(peer) },
            )
        }
        item {
            PrimaryButton(
                text = "Continue",
                onClick = onContinue,
                enabled = selected != null,
            )
        }
    }
}

@Composable
private fun ChooseFilesStep(onPick: () -> Unit) {
    LazyColumn(contentPadding = PaddingValues(bottom = SyncTokens.DockScrollPadding)) {
        item {
            AppCard {
                AppCardDesc("Select one or more files to send over Wi‑Fi.")
                Spacer(Modifier.height(SyncTokens.Space3))
                PrimaryButton(text = "Choose files", onClick = onPick)
            }
        }
    }
}

@Composable
private fun PreviewStep(
    files: List<PendingLocalFile>,
    peer: LocalPeer?,
    onSend: () -> Unit,
) {
    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space2),
        contentPadding = PaddingValues(bottom = SyncTokens.DockScrollPadding),
    ) {
        item {
            Text(
                "Sending to ${peer?.name ?: "device"}",
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(bottom = SyncTokens.Space2),
            )
        }
        items(files, key = { it.uri.toString() }) { file ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(SyncTokens.RadiusLg))
                    .background(AppSurfaces.card())
                    .border(1.dp, AppSurfaces.cardStroke(), RoundedCornerShape(SyncTokens.RadiusLg))
                    .padding(SyncTokens.Space4),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(file.name, maxLines = 1, modifier = Modifier.weight(1f))
                Text(formatBytes(file.size), color = SyncTokens.TextMuted, fontSize = 12.sp)
            }
        }
        item {
            Spacer(Modifier.height(SyncTokens.Space2))
            PrimaryButton(text = "Send now", onClick = onSend)
        }
    }
}

@Composable
private fun TransferStep(
    progress: com.syncbridge.android.localsend.LocalTransferProgress,
    manager: LocalSendManager,
    onPickMore: () -> Unit,
) {
    val context = LocalContext.current
    LazyColumn(contentPadding = PaddingValues(bottom = SyncTokens.DockScrollPadding)) {
        item {
            TransferCard(
                progress = progress,
                onCancel = manager::cancelTransfer,
                onOpenFolder = {
                    runCatching {
                        context.startActivity(Intent(DownloadManager.ACTION_VIEW_DOWNLOADS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        })
                    }
                },
                onSendMore = onPickMore,
                onDone = manager::clearCompletedTransfer,
            )
        }
    }
}

@Composable
private fun SuccessStep(
    peerName: String,
    onSendMore: () -> Unit,
    onDone: () -> Unit,
) {
    LazyColumn(
        horizontalAlignment = Alignment.CenterHorizontally,
        contentPadding = PaddingValues(bottom = SyncTokens.DockScrollPadding),
    ) {
        item {
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(CircleShape)
                    .background(SyncTokens.Success.copy(0.15f)),
                contentAlignment = Alignment.Center,
            ) {
                Text("✓", fontSize = 32.sp, color = SyncTokens.Success, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(SyncTokens.Space4))
            Text("Transfer complete", fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text("Delivered to $peerName over Wi‑Fi.", color = SyncTokens.TextMuted)
            Spacer(Modifier.height(SyncTokens.Space4))
            Row(horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
                GhostButton(text = "Send more", onClick = onSendMore)
                PrimaryButton(text = "Done", onClick = onDone)
            }
        }
    }
}

@Composable
private fun IncomingModal(offer: IncomingOffer, manager: LocalSendManager) {
    AppModal(
        title = "Incoming transfer",
        message = "${offer.offer.sender} wants to send:\n${offer.offer.files.joinToString { it.name }}",
        confirmText = "Accept",
        dismissText = "Decline",
        onConfirm = manager::acceptIncoming,
        onDismiss = manager::rejectIncoming,
    )
}

private fun resolveFiles(context: android.content.Context, uris: List<Uri>): List<PendingLocalFile> =
    uris.map { uri ->
        var name = uri.lastPathSegment ?: "file"
        var size = 0L
        context.contentResolver.query(uri, null, null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                c.getColumnIndex(OpenableColumns.DISPLAY_NAME).takeIf { it >= 0 }?.let { name = c.getString(it) ?: name }
                c.getColumnIndex(OpenableColumns.SIZE).takeIf { it >= 0 }?.let { size = c.getLong(it) }
            }
        }
        PendingLocalFile(uri, name, size)
    }
