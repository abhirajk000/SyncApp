package com.syncbridge.android.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import com.syncbridge.android.data.FileEntry
import com.syncbridge.android.ui.components.AppEmptyState
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.formatBytes
import com.syncbridge.android.util.relativeTime

@Composable
fun FilesScreen(
    files: List<FileEntry>,
    pinnedOnly: Boolean,
    onTogglePin: (FileEntry) -> Unit,
) {
    val filtered = files.filter { if (pinnedOnly) it.isPinned else !it.isPinned }

    LazyColumn(
        modifier = Modifier.padding(SyncTokens.Space4),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space2),
    ) {
        item { AppSectionTitle(if (pinnedOnly) "Pinned files" else "Temporary files") }
        if (filtered.isEmpty()) {
            item {
                AppEmptyState(
                    title = if (pinnedOnly) "No pinned files" else "No files yet",
                    description = "Upload from the Clipboard tab or receive files from other devices.",
                )
            }
        } else {
            items(filtered, key = { it.id }) { file ->
                Surface(
                    shape = RoundedCornerShape(SyncTokens.RadiusSm),
                    color = MaterialTheme.colorScheme.surface,
                    tonalElevation = 1.dp,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Row(Modifier.padding(SyncTokens.Space3), horizontalArrangement = Arrangement.SpaceBetween) {
                        Column(Modifier.weight(1f)) {
                            Text(file.name, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text(
                                "${formatBytes(file.totalSize)} · ${file.status} · ${relativeTime(file.createdAt)}",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        OutlinedButton(onClick = { onTogglePin(file) }) {
                            Text(if (file.isPinned) "Unpin" else "Pin")
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ImagesScreen(files: List<FileEntry>, onTogglePin: (FileEntry) -> Unit) {
    val images = files.filter { it.mimeType.startsWith("image/") }
    FilesScreen(files = images, pinnedOnly = false, onTogglePin = onTogglePin)
}
