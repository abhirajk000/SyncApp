package com.syncbridge.android.ui.screens

import android.widget.Toast
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.Modifier
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.ui.components.AppEmptyState
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.components.AppSurfaces
import com.syncbridge.android.ui.components.ClipboardCard
import com.syncbridge.android.ui.components.ContainerGroup
import com.syncbridge.android.ui.components.EmptyArt
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.copyEntryToClipboard
import com.syncbridge.android.util.isImageContentType
import kotlinx.coroutines.launch

/** Web ClipboardPage / PinnedPage parity. */
@Composable
fun PinnedScreen(
    entries: List<ClipboardEntry>,
    api: ApiClient,
    peerDeviceIds: Set<String> = emptySet(),
    onUnpin: (ClipboardEntry) -> Unit,
    onDelete: (ClipboardEntry) -> Unit = {},
    embedded: Boolean = false,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var copiedId by remember { mutableStateOf<String?>(null) }
    val pinned = entries
        .filter { it.pinned }
        .sortedByDescending { it.createdAt }

    fun copyEntry(entry: ClipboardEntry) {
        scope.launch {
            runCatching { copyEntryToClipboard(context, api, entry) }
                .onSuccess {
                    copiedId = entry.id
                    val msg = if (isImageContentType(entry.contentType)) "Image copied" else "Copied"
                    Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                }
                .onFailure { Toast.makeText(context, "Could not copy", Toast.LENGTH_SHORT).show() }
        }
    }

    LazyColumn(
        contentPadding = PaddingValues(
            start = SyncTokens.Space4,
            end = SyncTokens.Space4,
            top = if (embedded) SyncTokens.Space2 else SyncTokens.Space4,
            bottom = SyncTokens.DockScrollPadding,
        ),
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(SyncTokens.Space3),
    ) {
        if (!embedded) {
            item { AppSectionTitle("Pinned") }
        }
        if (pinned.isEmpty()) {
            item {
                AppEmptyState(
                    title = "No pinned items",
                    description = "Pin clipboard entries to keep them synced across all devices.",
                    illustration = EmptyArt.Pinned,
                )
            }
        } else {
            item {
                ContainerGroup {
                    pinned.forEachIndexed { index, entry ->
                        Column {
                            ClipboardCard(
                                entry = entry,
                                api = api,
                                transferMode = clipboardTransferMode(entry, peerDeviceIds),
                                copied = copiedId == entry.id,
                                embeddedInGroup = true,
                                onCopy = { copyEntry(entry) },
                                onDelete = { onDelete(entry) },
                                onPin = { onUnpin(entry) },
                                modifier = Modifier.fillMaxWidth(),
                            )
                            if (index < pinned.lastIndex) {
                                androidx.compose.material3.HorizontalDivider(
                                    modifier = Modifier.padding(horizontal = SyncTokens.Space5),
                                    color = AppSurfaces.cardStroke(),
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun clipboardTransferMode(entry: ClipboardEntry, peerDeviceIds: Set<String>): String =
    if (peerDeviceIds.contains(entry.sourceDeviceId)) "direct_lan" else "relay"
