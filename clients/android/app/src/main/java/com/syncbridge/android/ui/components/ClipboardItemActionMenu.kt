package com.syncbridge.android.ui.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.syncbridge.android.data.ClipboardEntry

@Composable
fun ClipboardItemActionMenu(
    entry: ClipboardEntry,
    modifier: Modifier = Modifier,
    onCopy: () -> Unit,
    onPin: () -> Unit,
    onDelete: () -> Unit,
) {
    ItemActionMenu(
        modifier = modifier,
        showDownload = false,
        showCopy = true,
        showPin = true,
        showDelete = !entry.pinned,
        isPinned = entry.pinned,
        onCopy = onCopy,
        onPin = onPin,
        onDelete = onDelete,
    )
}
