package com.syncbridge.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.syncbridge.android.ui.theme.SyncTokens

/** Web ds-item-delete-btn — circular delete control. */
@Composable
fun ItemDeleteButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    overlay: Boolean = false,
    label: String = "Delete",
) {
    val bg = if (overlay) Color(0x8C0F172A) else SyncTokens.Danger.copy(alpha = 0.1f)
    val tint = if (overlay) Color.White else SyncTokens.Danger
    Box(
        modifier = modifier
            .semantics { contentDescription = label }
            .size(28.dp)
            .clip(CircleShape)
            .background(bg)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            Icons.Outlined.Close,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(14.dp),
        )
    }
}
