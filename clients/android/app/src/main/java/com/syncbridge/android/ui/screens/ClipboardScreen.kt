package com.syncbridge.android.ui.screens

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.data.UploadProgress
import com.syncbridge.android.data.UploadStatus
import com.syncbridge.android.ui.components.AppCard
import com.syncbridge.android.ui.components.AppCardDesc
import com.syncbridge.android.ui.components.AppCardTitle
import com.syncbridge.android.ui.components.AppEmptyState
import com.syncbridge.android.ui.components.AppSectionTitle
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.relativeTime
import com.syncbridge.android.util.truncate
import java.io.File

@Composable
fun ClipboardScreen(
    latest: ClipboardEntry?,
    history: List<ClipboardEntry>,
    uploads: List<UploadProgress>,
    onSendText: (String) -> Unit,
    onUploadUris: (List<Uri>) -> Unit,
    onPin: (ClipboardEntry) -> Unit,
) {
    val clipboard = LocalClipboardManager.current
    var text by remember { mutableStateOf("") }

    val filePicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        if (uris.isNotEmpty()) onUploadUris(uris)
    }
    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia()) { uris ->
        if (uris.isNotEmpty()) onUploadUris(uris)
    }
    var cameraUri by remember { mutableStateOf<Uri?>(null) }
    val context = LocalContext.current

    val takePicture = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        if (success) cameraUri?.let { onUploadUris(listOf(it)) }
    }

    LazyColumn(
        modifier = Modifier.padding(SyncTokens.Space4),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
    ) {
        item {
            AppCard {
                AppCardTitle("Send Files")
                AppCardDesc("Choose from camera, gallery, or files on your device.")
                Row(horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
                    OutlinedButton(onClick = { filePicker.launch(arrayOf("*/*")) }) {
                        Text("Files")
                    }
                    OutlinedButton(onClick = {
                        photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    }) { Text("Gallery") }
                    OutlinedButton(onClick = {
                        val file = File(context.cacheDir, "camera/${System.currentTimeMillis()}.jpg").apply {
                            parentFile?.mkdirs()
                            createNewFile()
                        }
                        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
                        cameraUri = uri
                        takePicture.launch(uri)
                    }) { Text("Camera") }
                }
                uploads.forEach { u ->
                    Column(Modifier.padding(top = SyncTokens.Space2)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(u.name, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                            Text(
                                when (u.status) {
                                    UploadStatus.Success -> "Done"
                                    UploadStatus.Error -> u.error ?: "Failed"
                                    UploadStatus.Uploading -> "${(u.progress * 100).toInt()}%"
                                },
                                style = MaterialTheme.typography.labelMedium,
                            )
                        }
                        LinearProgressIndicator(
                            progress = { if (u.status == UploadStatus.Error) 0f else u.progress },
                            modifier = Modifier.fillMaxWidth().padding(top = SyncTokens.Space1),
                        )
                    }
                }
            }
        }

        item {
            AppCard {
                AppCardTitle("Send Text")
                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("Paste or type anything...") },
                    minLines = 4,
                )
                Button(
                    onClick = { onSendText(text); text = "" },
                    enabled = text.isNotBlank(),
                    modifier = Modifier.fillMaxWidth().padding(top = SyncTokens.Space3),
                ) { Text("Send") }
            }
        }

        item {
            AppSectionTitle("Latest Clipboard")
            AppCard(hero = true) {
                if (latest == null) {
                    Text("Nothing on the clipboard yet.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    Text(
                        relativeTime(latest.createdAt),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    Text(
                        truncate(latest.content, 500),
                        style = MaterialTheme.typography.bodyLarge,
                        modifier = Modifier.padding(vertical = SyncTokens.Space2),
                    )
                    OutlinedButton(onClick = { clipboard.setText(AnnotatedString(latest.content)) }) {
                        Text("Copy")
                    }
                }
            }
        }

        item { AppSectionTitle("History") }

        val temporary = history.filter { !it.pinned }
        if (temporary.isEmpty()) {
            item {
                AppEmptyState(
                    title = "No history yet",
                    description = "Items you send or copy will appear here.",
                )
            }
        } else {
            items(temporary, key = { it.id }) { entry ->
                HistoryRow(entry, onPin, clipboard)
            }
        }
    }
}

@Composable
private fun HistoryRow(
    entry: ClipboardEntry,
    onPin: (ClipboardEntry) -> Unit,
    clipboard: androidx.compose.ui.platform.ClipboardManager,
) {
    Surface(
        shape = RoundedCornerShape(SyncTokens.RadiusSm),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 1.dp,
        modifier = Modifier
            .fillMaxWidth()
            .clickable { clipboard.setText(AnnotatedString(entry.content)) },
    ) {
        Row(
            Modifier.padding(SyncTokens.Space3),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(Modifier.weight(1f)) {
                Text(entry.content, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Text(
                    "${entry.contentType} · ${relativeTime(entry.createdAt)}",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            OutlinedButton(onClick = { onPin(entry) }) { Text("Pin") }
        }
    }
}
