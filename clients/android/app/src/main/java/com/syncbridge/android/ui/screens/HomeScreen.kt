package com.syncbridge.android.ui.screens

import android.widget.Toast
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Refresh
import androidx.compose.material.icons.outlined.TextFields
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.data.FileEntry
import com.syncbridge.android.ui.MainTab
import com.syncbridge.android.ui.components.AppEmptyState
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.components.AppSurfaces
import com.syncbridge.android.ui.components.ClipboardImageThumb
import com.syncbridge.android.ui.components.ClipboardItemActionMenu
import com.syncbridge.android.ui.components.SectionHeaderRow
import com.syncbridge.android.ui.components.TrustedDevicesBar
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.clipboardDisplayText
import com.syncbridge.android.util.copyEntryToClipboard
import com.syncbridge.android.util.isImageContentType
import com.syncbridge.android.util.relativeTime
import kotlinx.coroutines.launch

@Composable
fun HomeScreen(
    history: List<ClipboardEntry>,
    files: List<FileEntry>,
    api: ApiClient,
    peerDeviceIds: Set<String> = emptySet(),
    isRefreshing: Boolean = false,
    onRefresh: () -> Unit = {},
    onTogglePinClipboard: (ClipboardEntry) -> Unit = {},
    onDeleteClipboard: (ClipboardEntry) -> Unit = {},
    onTogglePinFile: (FileEntry) -> Unit = {},
    onDeleteFile: (FileEntry) -> Unit = {},
    onNavigate: (MainTab) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    fun copyEntry(entry: ClipboardEntry) {
        scope.launch { copyEntryToClipboard(context, api, entry) }
    }

    val unpinnedSorted = history
        .filter { !it.pinned }
        .sortedByDescending { it.createdAt }
    val recentFiles = files
        .filter { !it.isPinned && it.status == "ready" }
        .sortedByDescending { it.createdAt }
        .take(12)

    val latest = unpinnedSorted.firstOrNull()
    val earlier = unpinnedSorted.drop(1)

    val isEmpty = latest == null && recentFiles.isEmpty()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            start = SyncTokens.Space4,
            end = SyncTokens.Space4,
            top = SyncTokens.Space4,
            bottom = SyncTokens.Space10 + SyncTokens.DockHeight,
        ),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Top,
            ) {
                Box(Modifier.weight(1f)) {
                    TrustedDevicesBar(api = api, peerDeviceIds = peerDeviceIds)
                }
                HomeRefreshButton(isRefreshing = isRefreshing, onClick = onRefresh)
            }
        }

        if (isEmpty) {
            item {
                AppEmptyState(
                    icon = Icons.Outlined.TextFields,
                    title = "Nothing synced yet",
                    description = "Copy text or an image on any device — it appears here automatically.",
                )
            }
            return@LazyColumn
        }

        latest?.let { entry ->
            item {
                AppSectionTitle("Latest")
                if (isImageContentType(entry.contentType)) {
                    HomeLatestImageCard(
                        entry = entry,
                        api = api,
                        onCopy = { copyEntry(entry) },
                        onPin = { onTogglePinClipboard(entry) },
                        onDelete = { onDeleteClipboard(entry) },
                    )
                } else {
                    HomeLatestTextCard(
                        entry = entry,
                        onCopy = { copyEntry(entry) },
                        onPin = { onTogglePinClipboard(entry) },
                        onDelete = { onDeleteClipboard(entry) },
                    )
                }
            }
        }

        if (earlier.isNotEmpty()) {
            item { AppSectionTitle("Earlier") }
            items(earlier, key = { it.id }) { entry ->
                if (isImageContentType(entry.contentType)) {
                    HomeEarlierImageRow(
                        entry = entry,
                        api = api,
                        onCopy = { copyEntry(entry) },
                        onPin = { onTogglePinClipboard(entry) },
                        onDelete = { onDeleteClipboard(entry) },
                    )
                } else {
                    HomeEarlierTextRow(
                        entry = entry,
                        onCopy = { copyEntry(entry) },
                        onPin = { onTogglePinClipboard(entry) },
                        onDelete = { onDeleteClipboard(entry) },
                    )
                }
            }
        }

        if (recentFiles.isNotEmpty()) {
            item {
                SectionHeaderRow(
                    title = "Recent files",
                    actionLabel = "See all",
                    onAction = { onNavigate(MainTab.Files) },
                )
            }
            items(recentFiles.chunked(2), key = { row -> row.joinToString { it.id } }) { row ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
                ) {
                    row.forEach { file ->
                        Box(Modifier.weight(1f)) {
                            FileGridCard(
                                file = file,
                                api = api,
                                onTogglePin = onTogglePinFile,
                                onDelete = onDeleteFile,
                                compact = true,
                            )
                        }
                    }
                    if (row.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun HomeRefreshButton(isRefreshing: Boolean, onClick: () -> Unit) {
    IconButton(
        onClick = onClick,
        enabled = !isRefreshing,
        modifier = Modifier
            .size(36.dp)
            .clip(CircleShape),
    ) {
        if (isRefreshing) {
            CircularProgressIndicator(
                modifier = Modifier.size(18.dp),
                strokeWidth = 2.dp,
                color = SyncTokens.Teal,
            )
        } else {
            Icon(
                Icons.Outlined.Refresh,
                contentDescription = "Refresh",
                tint = SyncTokens.Teal,
            )
        }
    }
}

@Composable
private fun HomeGlassCard(
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(SyncTokens.RadiusMd),
        color = AppSurfaces.card(),
        border = BorderStroke(1.dp, AppSurfaces.cardBorder()),
        shadowElevation = 1.dp,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Box(Modifier.padding(SyncTokens.Space4)) { content() }
    }
}

@Composable
private fun HomeLatestTextCard(
    entry: ClipboardEntry,
    onCopy: () -> Unit,
    onPin: () -> Unit,
    onDelete: () -> Unit,
) {
    Box(Modifier.fillMaxWidth()) {
        HomeGlassCard(onClick = onCopy) {
            Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space1)) {
                Text(
                    clipboardDisplayText(entry.content, 160),
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 3,
                    modifier = Modifier.padding(end = 36.dp),
                )
                Text(
                    relativeTime(entry.createdAt),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        ClipboardItemActionMenu(
            entry = entry,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(SyncTokens.Space2),
            onCopy = onCopy,
            onPin = onPin,
            onDelete = onDelete,
        )
    }
}

@Composable
private fun HomeLatestImageCard(
    entry: ClipboardEntry,
    api: ApiClient,
    onCopy: () -> Unit,
    onPin: () -> Unit,
    onDelete: () -> Unit,
) {
    Box(Modifier.fillMaxWidth()) {
        HomeGlassCard(onClick = onCopy) {
            Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
                ClipboardImageThumb(
                    entry = entry,
                    api = api,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(100.dp),
                    contentDescription = "Latest clipboard image",
                )
                Text(
                    "Tap to copy · ${relativeTime(entry.createdAt)}",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        ClipboardItemActionMenu(
            entry = entry,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(SyncTokens.Space2),
            onCopy = onCopy,
            onPin = onPin,
            onDelete = onDelete,
        )
    }
}

@Composable
private fun HomeEarlierTextRow(
    entry: ClipboardEntry,
    onCopy: () -> Unit,
    onPin: () -> Unit,
    onDelete: () -> Unit,
) {
    Box(Modifier.fillMaxWidth()) {
        HomeGlassCard(onClick = onCopy) {
            Row(horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
                Icon(
                    Icons.Outlined.Description,
                    contentDescription = null,
                    tint = SyncTokens.Teal,
                    modifier = Modifier
                        .size(16.dp)
                        .padding(top = 2.dp),
                )
                Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space1)) {
                    Text(
                        clipboardDisplayText(entry.content, 200),
                        style = MaterialTheme.typography.bodyMedium,
                        maxLines = 3,
                        modifier = Modifier.padding(end = 28.dp),
                    )
                    Text(
                        relativeTime(entry.createdAt),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
        ClipboardItemActionMenu(
            entry = entry,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(SyncTokens.Space2),
            onCopy = onCopy,
            onPin = onPin,
            onDelete = onDelete,
        )
    }
}

@Composable
private fun HomeEarlierImageRow(
    entry: ClipboardEntry,
    api: ApiClient,
    onCopy: () -> Unit,
    onPin: () -> Unit,
    onDelete: () -> Unit,
) {
    Box(Modifier.fillMaxWidth()) {
        HomeGlassCard(onClick = onCopy) {
            Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
                ClipboardImageThumb(
                    entry = entry,
                    api = api,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(80.dp),
                    contentDescription = "Clipboard image",
                )
                Text(
                    "Image · ${relativeTime(entry.createdAt)}",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        ClipboardItemActionMenu(
            entry = entry,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(SyncTokens.Space2),
            onCopy = onCopy,
            onPin = onPin,
            onDelete = onDelete,
        )
    }
}
