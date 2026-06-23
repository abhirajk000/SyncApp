package com.syncbridge.android.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.ui.components.AppEmptyState
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.components.ClipboardImageThumb
import com.syncbridge.android.ui.components.GlassListRow
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.clipboardDisplayText
import com.syncbridge.android.util.copyEntryToClipboard
import com.syncbridge.android.util.isImageContentType
import com.syncbridge.android.util.relativeTime
import kotlinx.coroutines.launch

@Composable
fun PinnedScreen(
    entries: List<ClipboardEntry>,
    api: ApiClient,
    onUnpin: (ClipboardEntry) -> Unit,
) {
    val clipboard = LocalClipboardManager.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val pinned = entries.filter { it.pinned }

    fun copyEntry(entry: ClipboardEntry) {
        scope.launch { copyEntryToClipboard(context, api, entry) }
    }

    LazyColumn(
        contentPadding = PaddingValues(
            start = SyncTokens.Space4,
            end = SyncTokens.Space4,
            top = SyncTokens.Space4,
            bottom = SyncTokens.Space10 + SyncTokens.DockHeight,
        ),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space3),
    ) {
        item { AppSectionTitle("Pinned") }
        if (pinned.isEmpty()) {
            item {
                AppEmptyState(
                    icon = Icons.Outlined.PushPin,
                    title = "No pinned items",
                    description = "Pin clipboard entries to keep them synced across devices.",
                )
            }
        } else {
            items(pinned, key = { it.id }) { entry ->
                GlassListRow(onClick = { copyEntry(entry) }) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Column(Modifier.weight(1f)) {
                            if (isImageContentType(entry.contentType)) {
                                ClipboardImageThumb(
                                    entry = entry,
                                    api = api,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(bottom = SyncTokens.Space2),
                                    contentDescription = "Pinned image",
                                )
                            } else {
                                Text(
                                    clipboardDisplayText(entry.content, 200),
                                    maxLines = 3,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }
                            Text(
                                relativeTime(entry.createdAt),
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        OutlinedButton(onClick = { onUnpin(entry) }) { Text("Unpin") }
                    }
                }
            }
        }
    }
}
