package com.syncbridge.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.clipboardDisplayText
import com.syncbridge.android.util.copyEntryToClipboard
import com.syncbridge.android.util.isImageContentType
import com.syncbridge.android.util.relativeTime
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun LatestClipboardDialog(
    entry: ClipboardEntry,
    api: ApiClient,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var copied by remember { mutableStateOf(false) }
    val isImage = isImageContentType(entry.contentType)

    fun copyAndDismiss() {
        scope.launch {
            copyEntryToClipboard(context, api, entry)
            copied = true
            delay(800)
            onDismiss()
        }
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.35f))
                .clickable(onClick = onDismiss),
            contentAlignment = Alignment.Center,
        ) {
            AppCard(
                modifier = Modifier
                    .padding(SyncTokens.Space4)
                    .fillMaxWidth()
                    .clickable(enabled = false) { },
                accentBorder = SyncTokens.Teal.copy(alpha = 0.22f),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        "Latest Clipboard",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.weight(1f),
                    )
                    TextButton(onClick = onDismiss) {
                        Text("✕", color = SyncTokens.SlateMuted)
                    }
                }
                Text(
                    relativeTime(entry.createdAt),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = SyncTokens.Space3),
                )
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(SyncTokens.RadiusMd))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f))
                        .clickable { copyAndDismiss() }
                        .padding(SyncTokens.Space4),
                ) {
                    if (isImage) {
                        ClipboardImageThumb(
                            entry = entry,
                            api = api,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(180.dp),
                            contentDescription = "Latest clipboard image",
                        )
                    } else {
                        Text(
                            clipboardDisplayText(entry.content, 500),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
                if (copied) {
                    Text(
                        if (isImage) "Copied image" else "Copied",
                        color = SyncTokens.Success,
                        style = MaterialTheme.typography.labelMedium,
                        modifier = Modifier.padding(top = SyncTokens.Space2),
                    )
                }
            }
        }
    }
}
