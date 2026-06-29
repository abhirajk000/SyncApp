package com.syncbridge.android.ui.screens

import android.widget.Toast
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.data.FileEntry
import com.syncbridge.android.ui.MainTab
import com.syncbridge.android.ui.components.AppEmptyState
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.components.ChipVariant
import com.syncbridge.android.ui.components.ClipboardCard
import com.syncbridge.android.ui.components.EarlierImageRow
import com.syncbridge.android.ui.components.EarlierTextRow
import com.syncbridge.android.ui.components.EmptyArt
import com.syncbridge.android.ui.components.GlassListRow
import com.syncbridge.android.ui.components.LatestImageCard
import com.syncbridge.android.ui.components.LatestTextCard
import com.syncbridge.android.ui.components.PremiumChip
import com.syncbridge.android.ui.components.SectionHeaderRow
import com.syncbridge.android.ui.components.TrustedDevicesBar
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.clipboardDisplayText
import com.syncbridge.android.util.copyEntryToClipboard
import com.syncbridge.android.util.formatBytes
import com.syncbridge.android.util.isImageContentType
import com.syncbridge.android.util.relativeTime
import kotlinx.coroutines.launch
import java.time.Instant

private const val RECENT_FILES_LIMIT = 8
private const val PINNED_PREVIEW_LIMIT = 5
private const val ACTIVITY_LIMIT = 10

private data class ActivityItem(
    val id: String,
    val at: String,
    val kind: String,
    val label: String,
    val entry: ClipboardEntry? = null,
)

@Composable
fun HomeScreen(
    history: List<ClipboardEntry>,
    files: List<FileEntry>,
    api: ApiClient,
    peerDeviceIds: Set<String> = emptySet(),
    onDeleteClipboard: (ClipboardEntry) -> Unit = {},
    onTogglePinFile: (FileEntry) -> Unit = {},
    onDeleteFile: (FileEntry) -> Unit = {},
    onNavigate: (MainTab) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    fun copyEntry(entry: ClipboardEntry) {
        scope.launch {
            runCatching { copyEntryToClipboard(context, api, entry) }
                .onSuccess { Toast.makeText(context, "Copied", Toast.LENGTH_SHORT).show() }
                .onFailure { Toast.makeText(context, "Could not copy", Toast.LENGTH_SHORT).show() }
        }
    }

    val unpinned = history.filter { !it.pinned }.sortedByDescending { it.createdAt }
    val pinned = history.filter { it.pinned }.sortedByDescending { it.createdAt }.take(PINNED_PREVIEW_LIMIT)
    val pinnedFiles = files.filter { it.isPinned && it.status == "ready" }.sortedByDescending { it.createdAt }.take(4)
    val recentFiles = files.filter { !it.isPinned && it.status == "ready" }.sortedByDescending { it.createdAt }.take(RECENT_FILES_LIMIT)

    val latestText = unpinned.firstOrNull { !isImageContentType(it.contentType) }
    val latestImage = unpinned.firstOrNull { isImageContentType(it.contentType) }
    val earlier = unpinned.filter { it != latestText && it != latestImage }

    val activity = buildList {
        history.forEach { add(ActivityItem("clip-${it.id}", it.createdAt, "Clipboard", activityClipboardLabel(it), it)) }
        files.filter { it.status == "ready" }.forEach {
            add(ActivityItem("file-${it.id}", it.createdAt, "File", "${it.name} · ${formatBytes(it.totalSize)}"))
        }
    }.sortedByDescending { parseInstant(it.at) }.take(ACTIVITY_LIMIT)

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            start = SyncTokens.Space4,
            end = SyncTokens.Space4,
            top = SyncTokens.Space4,
            bottom = SyncTokens.Space10 + SyncTokens.DockHeight,
        ),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space8),
    ) {
        // Clipboard
        item {
            Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4)) {
                AppSectionTitle("Clipboard")
                if (unpinned.isEmpty()) {
                    AppEmptyState(
                        title = "No clipboard items",
                        description = "Copy text or an image on any device — it appears here automatically.",
                        illustration = EmptyArt.Clipboard,
                    )
                } else {
                    latestText?.let { entry ->
                        LatestTextCard(
                            entry = entry,
                            title = "Latest text",
                            onCopy = { copyEntry(entry) },
                        )
                    }
                    latestImage?.let { entry ->
                        LatestImageCard(
                            entry = entry,
                            api = api,
                            title = "Latest image",
                            onCopy = { copyEntry(entry) },
                        )
                    }
                    if (earlier.isNotEmpty()) {
                        Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
                            earlier.forEach { entry ->
                                if (isImageContentType(entry.contentType)) {
                                    EarlierImageRow(entry = entry, api = api, onCopy = { copyEntry(entry) })
                                } else {
                                    EarlierTextRow(entry = entry, onCopy = { copyEntry(entry) })
                                }
                            }
                        }
                    }
                }
            }
        }

        // Pinned
        if (pinned.isNotEmpty() || pinnedFiles.isNotEmpty()) {
            item {
                Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4)) {
                    SectionHeaderRow(
                        title = "Pinned",
                        actionLabel = "See all",
                        onAction = { onNavigate(MainTab.Clipboard) },
                    )
                    pinned.forEach { entry ->
                        ClipboardCard(
                            entry = entry,
                            onCopy = { copyEntry(entry) },
                            onDelete = { onDeleteClipboard(entry) },
                        )
                    }
                    if (pinnedFiles.isNotEmpty()) {
                        LazyVerticalGrid(
                            columns = GridCells.Adaptive(minSize = 148.dp),
                            horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
                            verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(pinnedFilesGridHeight(pinnedFiles.size)),
                            userScrollEnabled = false,
                        ) {
                            items(pinnedFiles, key = { it.id }) { file ->
                                FileGridCard(
                                    file = file,
                                    api = api,
                                    onTogglePin = onTogglePinFile,
                                    onDelete = onDeleteFile,
                                    compact = true,
                                )
                            }
                        }
                    }
                }
            }
        }

        // Files
        item {
            Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4)) {
                SectionHeaderRow(
                    title = "Files",
                    actionLabel = "See all",
                    onAction = { onNavigate(MainTab.Files) },
                )
                if (recentFiles.isEmpty()) {
                    AppEmptyState(
                        title = "No files yet",
                        description = "Send files from another device — they appear here when ready.",
                        illustration = EmptyArt.Files,
                    )
                } else {
                    LazyVerticalGrid(
                        columns = GridCells.Adaptive(minSize = 148.dp),
                        horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
                        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(recentFilesGridHeight(recentFiles.size)),
                        userScrollEnabled = false,
                    ) {
                        items(recentFiles, key = { it.id }) { file ->
                            FileGridCard(
                                file = file,
                                api = api,
                                onTogglePin = onTogglePinFile,
                                onDelete = onDeleteFile,
                                compact = true,
                            )
                        }
                    }
                }
            }
        }

        // Trusted devices
        item {
            TrustedDevicesBar(api = api, peerDeviceIds = peerDeviceIds)
        }

        // Recent activity
        if (activity.isNotEmpty()) {
            item {
                Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4)) {
                    AppSectionTitle("Recent activity")
                    Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
                        activity.forEach { item ->
                            val entry = item.entry
                            GlassListRow(
                                onClick = if (entry != null) ({ copyEntry(entry) }) else null,
                            ) {
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2),
                                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                                ) {
                                    PremiumChip(
                                        label = item.kind,
                                        variant = if (item.kind == "Clipboard") ChipVariant.Primary else ChipVariant.Neutral,
                                    )
                                    Text(
                                        relativeTime(item.at),
                                        fontSize = 12.sp,
                                        color = SyncTokens.SlateMuted,
                                    )
                                }
                                Text(
                                    item.label,
                                    style = MaterialTheme.typography.bodyMedium,
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier.padding(top = SyncTokens.Space1),
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun activityClipboardLabel(entry: ClipboardEntry): String =
    if (isImageContentType(entry.contentType)) "Image copied"
    else clipboardDisplayText(entry.content, 120)

private fun parseInstant(iso: String): Instant =
    runCatching { Instant.parse(iso) }.getOrDefault(Instant.EPOCH)

private fun recentFilesGridHeight(count: Int): androidx.compose.ui.unit.Dp {
    val columns = 2
    val rows = (count + columns - 1) / columns
    val cell = 148.dp + 40.dp
    return cell * rows + SyncTokens.Space4 * (rows - 1).coerceAtLeast(0)
}

private fun pinnedFilesGridHeight(count: Int) = recentFilesGridHeight(count)
