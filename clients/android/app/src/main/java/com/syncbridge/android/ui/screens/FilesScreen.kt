package com.syncbridge.android.ui.screens

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Archive
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.InsertDriveFile
import androidx.compose.material.icons.outlined.Movie
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.FileEntry
import com.syncbridge.android.ui.components.AppEmptyState
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.formatBytes
import com.syncbridge.android.util.relativeTime
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private enum class FileTab { Temporary, Pinned }

@Composable
fun FilesScreen(
    files: List<FileEntry>,
    api: ApiClient,
    onTogglePin: (FileEntry) -> Unit,
) {
    var tab by remember { mutableStateOf(FileTab.Temporary) }
    val filtered = files.filter { if (tab == FileTab.Pinned) it.isPinned else !it.isPinned }

    Column(Modifier.padding(SyncTokens.Space4)) {
        Row(horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
            FilterChip(
                selected = tab == FileTab.Temporary,
                onClick = { tab = FileTab.Temporary },
                label = { Text("Temporary") },
            )
            FilterChip(
                selected = tab == FileTab.Pinned,
                onClick = { tab = FileTab.Pinned },
                label = { Text("Pinned") },
            )
        }

        AppSectionTitle(if (tab == FileTab.Pinned) "Pinned files" else "Temporary files")

        if (filtered.isEmpty()) {
            AppEmptyState(
                title = if (tab == FileTab.Pinned) "No pinned files" else "No files yet",
                description = "Send files from the Send tab or receive them from other devices.",
            )
        } else if (tab == FileTab.Temporary) {
            LazyVerticalGrid(
                columns = GridCells.Adaptive(minSize = 120.dp),
                horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
                verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
                modifier = Modifier.padding(top = SyncTokens.Space3),
            ) {
                items(filtered, key = { it.id }) { file ->
                    FileGridCard(file = file, api = api, onTogglePin = onTogglePin)
                }
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
                filtered.forEach { file ->
                    PinnedFileRow(file, onTogglePin)
                }
            }
        }
    }
}

@Composable
private fun PinnedFileRow(file: FileEntry, onTogglePin: (FileEntry) -> Unit) {
    Surface(
        shape = RoundedCornerShape(SyncTokens.RadiusSm),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 1.dp,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            Modifier.padding(SyncTokens.Space3),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(file.name, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(
                    "${formatBytes(file.totalSize)} · ${relativeTime(file.createdAt)}",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            OutlinedButton(onClick = { onTogglePin(file) }) { Text("Unpin") }
        }
    }
}

@Composable
fun FileGridCard(
    file: FileEntry,
    api: ApiClient,
    onTogglePin: (FileEntry) -> Unit,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space2),
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1f),
            shape = RoundedCornerShape(SyncTokens.RadiusXl),
            color = Color.White,
            shadowElevation = 6.dp,
        ) {
            FilePreviewContent(file = file, api = api)
        }
        Text(
            file.name,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(horizontal = SyncTokens.Space1),
        )
        OutlinedButton(onClick = { onTogglePin(file) }, modifier = Modifier.padding(bottom = SyncTokens.Space1)) {
            Text("Pin", fontSize = 11.sp)
        }
    }
}

@Composable
private fun FilePreviewContent(file: FileEntry, api: ApiClient) {
    val mime = file.mimeType
    val ext = file.name.substringAfterLast('.', "").lowercase()
    var bitmap by remember(file.id) { mutableStateOf<android.graphics.Bitmap?>(null) }
    var textPreview by remember(file.id) { mutableStateOf<String?>(null) }

    LaunchedEffect(file.id, file.status) {
        if (file.status != "ready") return@LaunchedEffect
        withContext(Dispatchers.IO) {
            if (mime.startsWith("image/")) {
                val bytes = api.downloadThumbnailBytes(file.id)
                    ?: if (file.totalSize <= 2 * 1024 * 1024) api.downloadFileBytes(file.id) else null
                bytes?.let { bitmap = BitmapFactory.decodeByteArray(it, 0, it.size) }
            } else if (mime.startsWith("text/") || ext in setOf("txt", "md", "csv", "json", "log")) {
                if (file.totalSize <= 512 * 1024) {
                    val bytes = api.downloadFileBytes(file.id)
                    textPreview = String(bytes, 0, minOf(bytes.size, 4096)).take(1200)
                }
            }
        }
    }

    if (file.status != "ready") {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("Uploading…", fontSize = 11.sp, color = Color(0xFF64748B))
        }
        return
    }

    when {
        bitmap != null -> {
            Image(
                bitmap = bitmap!!.asImageBitmap(),
                contentDescription = file.name,
                modifier = Modifier.fillMaxSize().padding(6.dp),
                contentScale = ContentScale.Fit,
            )
        }
        textPreview != null -> {
            Text(
                textPreview!!,
                modifier = Modifier.fillMaxSize().padding(10.dp),
                fontSize = 7.sp,
                lineHeight = 9.sp,
                color = Color(0xFF1E293B),
            )
        }
        else -> {
            val icon = when {
                mime.startsWith("video/") -> Icons.Outlined.Movie
                mime.contains("zip") || mime.contains("tar") -> Icons.Outlined.Archive
                mime.contains("pdf") || mime.contains("word") -> Icons.Outlined.Description
                mime.startsWith("image/") -> Icons.Outlined.Image
                else -> Icons.Outlined.InsertDriveFile
            }
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(icon, contentDescription = null, tint = Color(0xFF64748B))
                    if (ext.isNotBlank()) {
                        Text(
                            ext.uppercase(),
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF94A3B8),
                        )
                    }
                }
            }
        }
    }
}
