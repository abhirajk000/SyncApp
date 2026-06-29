package com.syncbridge.android.ui.screens

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import com.syncbridge.android.ui.components.SegmentedTabs
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.FileEntry
import androidx.compose.material.icons.outlined.Folder
import com.syncbridge.android.ui.components.AppEmptyState
import com.syncbridge.android.ui.components.EmptyArt
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.components.ContainerGroup
import com.syncbridge.android.ui.components.ContainerGroupItem
import com.syncbridge.android.ui.components.GlassListRow
import com.syncbridge.android.ui.components.ItemActionMenu
import com.syncbridge.android.ui.components.SurfaceCard
import com.syncbridge.android.ui.components.TransferBadge
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.canCopyFile
import com.syncbridge.android.util.copyFileToClipboard
import com.syncbridge.android.util.downloadFileToDevice
import com.syncbridge.android.util.decodeThumbnailBitmap
import com.syncbridge.android.util.formatBytes
import com.syncbridge.android.util.relativeTime
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private enum class FileTab { Temporary, Pinned }

@Composable
fun FilesScreen(
    files: List<FileEntry>,
    api: ApiClient,
    onTogglePin: (FileEntry) -> Unit,
    onDelete: (FileEntry) -> Unit = {},
) {
    var tab by remember { mutableStateOf(FileTab.Temporary) }
    val filtered = files.filter { if (tab == FileTab.Pinned) it.isPinned else !it.isPinned }

    Column(
        Modifier
            .fillMaxSize()
            .padding(
                PaddingValues(
                    start = SyncTokens.Space4,
                    end = SyncTokens.Space4,
                    top = SyncTokens.Space4,
                    bottom = SyncTokens.DockScrollPadding,
                ),
            ),
    ) {
        SegmentedTabs(
            options = listOf("Temporary", "Pinned"),
            selectedIndex = if (tab == FileTab.Temporary) 0 else 1,
            onSelect = { tab = if (it == 0) FileTab.Temporary else FileTab.Pinned },
            modifier = Modifier.padding(bottom = SyncTokens.Space4),
        )

        AppSectionTitle(if (tab == FileTab.Pinned) "Pinned files" else "Temporary files")

        if (filtered.isEmpty()) {
            AppEmptyState(
                title = if (tab == FileTab.Pinned) "No pinned files" else "No files yet",
                description = "Receive files via Local Send or from cloud sync on other devices.",
                illustration = EmptyArt.Files,
            )
        } else if (tab == FileTab.Temporary) {
            LazyVerticalGrid(
                columns = GridCells.Adaptive(minSize = 120.dp),
                horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
                verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
                modifier = Modifier
                    .weight(1f)
                    .padding(top = SyncTokens.Space3),
            ) {
                items(filtered, key = { it.id }) { file ->
                    FileGridCard(
                        file = file,
                        api = api,
                        onTogglePin = onTogglePin,
                        onDelete = onDelete,
                    )
                }
            }
        } else {
            ContainerGroup(modifier = Modifier.weight(1f)) {
                filtered.forEachIndexed { index, file ->
                    ContainerGroupItem(showDivider = index < filtered.lastIndex) {
                        PinnedFileRowContent(file, api, onTogglePin, onDelete)
                    }
                }
            }
        }
    }
}

@Composable
private fun PinnedFileRowContent(
    file: FileEntry,
    api: ApiClient,
    onTogglePin: (FileEntry) -> Unit,
    onDelete: (FileEntry) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val ready = file.status == "ready"

    Row(
        modifier = Modifier.fillMaxWidth(),
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
                TransferBadge(transferMode = file.transferMode)
            }
            ItemActionMenu(
                showDownload = ready,
                showCopy = canCopyFile(file),
                showPin = true,
                showDelete = true,
                isPinned = true,
                onDownload = {
                    scope.launch {
                        runCatching { downloadFileToDevice(context, api, file) }
                    }
                },
                onCopy = {
                    scope.launch {
                        runCatching { copyFileToClipboard(context, api, file) }
                    }
                },
                onPin = { onTogglePin(file) },
            )
    }
}

@Composable
fun FileGridCard(
    file: FileEntry,
    api: ApiClient,
    onTogglePin: (FileEntry) -> Unit,
    onDelete: (FileEntry) -> Unit = {},
    compact: Boolean = false,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val ready = file.status == "ready"

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(if (compact) SyncTokens.Space1 else SyncTokens.Space2),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1f),
        ) {
            SurfaceCard(
                modifier = Modifier.fillMaxSize(),
                shape = RoundedCornerShape(if (compact) SyncTokens.RadiusLg else SyncTokens.RadiusXl),
            ) {
                FilePreviewContent(file = file, api = api)
            }
            ItemActionMenu(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(SyncTokens.Space2)
                    .zIndex(2f),
                showDownload = ready,
                showCopy = canCopyFile(file),
                showPin = true,
                showDelete = true,
                isPinned = file.isPinned,
                onDownload = {
                    scope.launch {
                        runCatching { downloadFileToDevice(context, api, file) }
                    }
                },
                onCopy = {
                    scope.launch {
                        runCatching { copyFileToClipboard(context, api, file) }
                    }
                },
                onPin = { onTogglePin(file) },
                onDelete = { onDelete(file) },
            )
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
        if (!compact) {
            TransferBadge(transferMode = file.transferMode)
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
                bytes?.let { bitmap = decodeThumbnailBitmap(it) }
            } else if (mime.startsWith("text/") || ext in setOf("txt", "md", "csv", "json", "log")) {
                if (file.totalSize <= 512 * 1024) {
                    val bytes = api.downloadFileBytes(file.id)
                    textPreview = String(bytes, 0, minOf(bytes.size, 4096)).take(1200)
                }
            }
        }
    }

    DisposableEffect(file.id) {
        onDispose {
            bitmap?.recycle()
            bitmap = null
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
