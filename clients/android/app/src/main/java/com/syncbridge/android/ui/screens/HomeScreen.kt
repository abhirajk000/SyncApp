package com.syncbridge.android.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.InsertDriveFile
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.data.FileEntry
import com.syncbridge.android.ui.MainTab
import com.syncbridge.android.ui.components.AppCard
import com.syncbridge.android.ui.components.AppEmptyState
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.formatBytes
import com.syncbridge.android.util.relativeTime
import com.syncbridge.android.util.truncate

@Composable
fun HomeScreen(
    history: List<ClipboardEntry>,
    files: List<FileEntry>,
    onNavigate: (MainTab) -> Unit,
) {
    val clipboard = LocalClipboardManager.current
    val recent = history.filter { !it.pinned }.take(6)
    val recentFiles = files.filter { !it.isPinned && it.status == "ready" }.take(5)

    LazyColumn(
        modifier = Modifier.padding(SyncTokens.Space4),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space6),
    ) {
        item {
            AppSectionTitle("Recent clipboard")
            if (recent.isEmpty()) {
                AppCard {
                    Text(
                        "No clipboard items yet.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
        items(recent, key = { it.id }) { entry ->
            Surface(
                shape = RoundedCornerShape(SyncTokens.RadiusMd),
                color = MaterialTheme.colorScheme.surface,
                tonalElevation = 1.dp,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { clipboard.setText(AnnotatedString(entry.content)) },
            ) {
                Column(Modifier.padding(SyncTokens.Space3)) {
                    Text(truncate(entry.content, 200), maxLines = 2, overflow = TextOverflow.Ellipsis)
                    Text(
                        "${entry.contentType} · ${relativeTime(entry.createdAt)}",
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
                AppSectionTitle("Recent files")
                TextButton(onClick = { onNavigate(MainTab.Files) }) { Text("See all") }
            }
            if (recentFiles.isEmpty()) {
                AppCard {
                    Text("No files yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        items(recentFiles, key = { it.id }) { file ->
            Surface(
                shape = RoundedCornerShape(SyncTokens.RadiusMd),
                color = MaterialTheme.colorScheme.surface,
                tonalElevation = 1.dp,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Row(Modifier.padding(SyncTokens.Space3), horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space3)) {
                    androidx.compose.material3.Icon(
                        Icons.Outlined.InsertDriveFile,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                    )
                    Column {
                        Text(file.name, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(
                            "${formatBytes(file.totalSize)} · ${relativeTime(file.createdAt)}",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }
}
