package com.syncbridge.android.ui.screens

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.syncbridge.android.data.UploadProgress
import com.syncbridge.android.data.UploadStatus
import com.syncbridge.android.ui.components.AppCard
import com.syncbridge.android.ui.components.AppCardDesc
import com.syncbridge.android.ui.components.AppCardTitle
import com.syncbridge.android.ui.theme.SyncTokens
import java.io.File

@Composable
fun SendScreen(
    uploads: List<UploadProgress>,
    onSendText: (String) -> Unit,
    onUploadUris: (List<Uri>) -> Unit,
) {
    var text by remember { mutableStateOf("") }
    val context = LocalContext.current

    val filePicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        if (uris.isNotEmpty()) onUploadUris(uris)
    }
    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia()) { uris ->
        if (uris.isNotEmpty()) onUploadUris(uris)
    }
    var cameraUri by remember { mutableStateOf<Uri?>(null) }
    val takePicture = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        if (success) cameraUri?.let { onUploadUris(listOf(it)) }
    }

    LazyColumn(
        modifier = Modifier.padding(SyncTokens.Space4),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
    ) {
        item {
            Text(
                "Send text, images, or files to your connected devices.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        item {
            AppCard {
                AppCardTitle("Send Text")
                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text("Paste or type anything...") },
                    minLines = 5,
                    shape = RoundedCornerShape(SyncTokens.RadiusSm),
                )
                Button(
                    onClick = { onSendText(text); text = "" },
                    enabled = text.isNotBlank(),
                    modifier = Modifier.fillMaxWidth().padding(top = SyncTokens.Space3),
                ) { Text("Send") }
            }
        }
        item {
            AppCard {
                AppCardTitle("Send Files")
                AppCardDesc("Choose from camera, gallery, or files on your device.")
                Row(horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2)) {
                    OutlinedButton(onClick = { filePicker.launch(arrayOf("*/*")) }) { Text("Files") }
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
    }
}
