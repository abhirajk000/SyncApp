package com.syncbridge.android.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.InsertDriveFile
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.data.FileEntry
import com.syncbridge.android.ui.MainTab
import com.syncbridge.android.ui.components.AppCard
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.components.GlassListRow
import com.syncbridge.android.ui.components.TransferBadge
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.formatBytes
import com.syncbridge.android.util.isImageContentType
import com.syncbridge.android.util.relativeTime
import com.syncbridge.android.util.truncate

@Composable
fun HomeScreen(
    history: List<ClipboardEntry>,
    files: List<FileEntry>,
    onNavigate: (MainTab) -> Unit,
) {
    val clipboard = LocalClipboardManager.current
    val textEntry = history.firstOrNull { !it.pinned && !isImageContentType(it.contentType) }
    val imageEntry = history.firstOrNull { !it.pinned && isImageContentType(it.contentType) }
    val latestFile = files.firstOrNull { !it.isPinned && it.status == "ready" }

    LazyColumn(
        modifier = Modifier.padding(SyncTokens.Space4),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space6),
    ) {
        item {
            AppSectionTitle("Latest text")
            if (textEntry == null) {
                AppCard { Text("No text yet.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
            } else {
                GlassListRow(onClick = { clipboard.setText(AnnotatedString(textEntry.content)) }) {
                    Text(truncate(textEntry.content, 300), maxLines = 4, overflow = TextOverflow.Ellipsis)
                    Text(
                        relativeTime(textEntry.createdAt),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        item {
            AppSectionTitle("Latest image")
            if (imageEntry == null) {
                AppCard { Text("No images yet.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
            } else {
                GlassListRow(onClick = { clipboard.setText(AnnotatedString("[Image — open Files or tap notification]")) }) {
                    Text(
                        if (isImageContentType(imageEntry.contentType)) "Image · ${imageEntry.contentType}" else imageEntry.content,
                        maxLines = 2,
                    )
                    Text(
                        relativeTime(imageEntry.createdAt),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
            ) {
                AppSectionTitle("Latest file")
                TextButton(onClick = { onNavigate(MainTab.Files) }) { Text("See all") }
            }
            if (latestFile == null) {
                AppCard { Text("No files yet.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
            } else {
                GlassListRow {
                    Row(horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space3)) {
                        androidx.compose.material3.Icon(
                            Icons.Outlined.InsertDriveFile,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                        )
                        Column {
                            Text(latestFile.name, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text(
                                "${formatBytes(latestFile.totalSize)} · ${relativeTime(latestFile.createdAt)}",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            TransferBadge(transferMode = latestFile.transferMode)
                        }
                    }
                }
            }
        }
    }
}
