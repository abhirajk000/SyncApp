package com.syncbridge.android.ui.screens

import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.UploadFile
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import com.syncbridge.android.ui.components.PremiumLinearProgress
import com.syncbridge.android.ui.components.PremiumTextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
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
import com.syncbridge.android.ui.components.AppSurfaces
import com.syncbridge.android.ui.components.GhostButton
import com.syncbridge.android.ui.components.PrimaryButton
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

    fun toast(msg: String) = Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()

    val filePicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        uris.forEach { uri ->
            try {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (_: Exception) {
                // Best-effort — read may still work in-session.
            }
        }
        if (uris.isNotEmpty()) {
            onUploadUris(uris)
            toast("Uploading ${uris.size} file(s)…")
        }
    }
    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia()) { uris ->
        if (uris.isNotEmpty()) onUploadUris(uris)
    }
    var cameraUri by remember { mutableStateOf<Uri?>(null) }
    val takePicture = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        if (success) cameraUri?.let { onUploadUris(listOf(it)) }
    }

    LazyColumn(
        contentPadding = PaddingValues(
            start = SyncTokens.Space4,
            end = SyncTokens.Space4,
            top = SyncTokens.Space4,
            bottom = SyncTokens.DockScrollPadding,
        ),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space6),
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
                AppCardTitle("Quick send text")
                PremiumTextField(
                    value = text,
                    onValueChange = { text = it },
                    placeholder = "Paste or type anything…",
                    singleLine = false,
                    minLines = 5,
                )
                PrimaryButton(
                    text = "Send",
                    onClick = {
                        onSendText(text)
                        text = ""
                        toast("Sent")
                    },
                    enabled = text.isNotBlank(),
                    modifier = Modifier.padding(top = SyncTokens.Space3),
                )
            }
        }
        item {
            AppCard {
                AppCardTitle("Send image")
                AppCardDesc("Pick from gallery or take a photo.")
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(120.dp)
                        .border(1.dp, AppSurfaces.cardBorder(), RoundedCornerShape(SyncTokens.RadiusLg))
                        .padding(SyncTokens.Space4),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Icon(Icons.Outlined.Image, contentDescription = null, tint = SyncTokens.SlateMuted)
                    Row(horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2), modifier = Modifier.padding(top = SyncTokens.Space3)) {
                        GhostButton(text = "Gallery", onClick = {
                            photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                        })
                        GhostButton(text = "Camera", onClick = {
                            val file = File(context.cacheDir, "camera/${System.currentTimeMillis()}.jpg").apply {
                                parentFile?.mkdirs()
                                createNewFile()
                            }
                            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
                            cameraUri = uri
                            takePicture.launch(uri)
                        })
                    }
                }
            }
        }
        item {
            AppCard {
                AppCardTitle("Send files")
                AppCardDesc("Upload documents and other files to your devices.")
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(1.dp, AppSurfaces.cardBorder(), RoundedCornerShape(SyncTokens.RadiusLg))
                        .padding(SyncTokens.Space8, SyncTokens.Space6),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(SyncTokens.Space3),
                ) {
                    Icon(Icons.Outlined.UploadFile, contentDescription = null, tint = SyncTokens.SlateMuted)
                    Text("Choose files from your device", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    GhostButton(text = "Browse files", onClick = { filePicker.launch(arrayOf("*/*")) })
                }
                uploads.forEach { u ->
                    Column(Modifier.padding(top = SyncTokens.Space3)) {
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
                        PremiumLinearProgress(
                            progress = if (u.status == UploadStatus.Error) 0f else u.progress,
                            modifier = Modifier.padding(top = SyncTokens.Space1),
                        )
                    }
                }
            }
        }
    }
}
