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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.ui.components.AppEmptyState
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.relativeTime

@Composable
fun PinnedScreen(
    entries: List<ClipboardEntry>,
    onUnpin: (ClipboardEntry) -> Unit,
) {
    val clipboard = LocalClipboardManager.current
    val pinned = entries.filter { it.pinned }

    LazyColumn(
        modifier = Modifier.padding(SyncTokens.Space4),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space2),
    ) {
        item { AppSectionTitle("Pinned") }
        if (pinned.isEmpty()) {
            item {
                AppEmptyState(
                    title = "No pinned items",
                    description = "Pin clipboard entries to keep them synced across devices.",
                )
            }
        } else {
            items(pinned, key = { it.id }) { entry ->
                Surface(
                    shape = RoundedCornerShape(SyncTokens.RadiusSm),
                    color = MaterialTheme.colorScheme.surface,
                    tonalElevation = 1.dp,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { clipboard.setText(AnnotatedString(entry.content)) },
                ) {
                    Row(Modifier.padding(SyncTokens.Space3), horizontalArrangement = Arrangement.SpaceBetween) {
                        Column(Modifier.weight(1f)) {
                            Text(entry.content, maxLines = 3, overflow = TextOverflow.Ellipsis)
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
