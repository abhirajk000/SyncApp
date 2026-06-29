package com.syncbridge.android.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.decodeThumbnailBitmap
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Composable
fun ClipboardImageThumb(
    entry: ClipboardEntry,
    api: ApiClient,
    modifier: Modifier = Modifier,
    contentDescription: String? = null,
) {
    var bitmap by remember(entry.id) { mutableStateOf<android.graphics.Bitmap?>(null) }

    LaunchedEffect(entry.id) {
        withContext(Dispatchers.IO) {
            val bytes = api.downloadClipboardThumbnailBytes(entry.id) ?: return@withContext
            decodeThumbnailBitmap(bytes)?.let { decoded ->
                bitmap = decoded
            }
        }
    }

    DisposableEffect(entry.id) {
        onDispose {
            bitmap?.recycle()
            bitmap = null
        }
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(SyncTokens.RadiusMd))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(0.4f)),
        contentAlignment = Alignment.Center,
    ) {
        if (bitmap != null) {
            Image(
                bitmap = bitmap!!.asImageBitmap(),
                contentDescription = contentDescription,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Fit,
            )
        }
    }
}
