package com.syncbridge.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.Download
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.syncbridge.android.ui.theme.SyncTokens

private val menuGradient = Brush.linearGradient(
    colors = listOf(
        Color(0xF21A2234),
        Color(0xF80F1218),
    ),
)

@Composable
fun ItemActionMenu(
    modifier: Modifier = Modifier,
    showDownload: Boolean = true,
    showCopy: Boolean = true,
    showPin: Boolean = true,
    showDelete: Boolean = true,
    isPinned: Boolean = false,
    onDownload: () -> Unit = {},
    onCopy: () -> Unit = {},
    onPin: () -> Unit = {},
    onDelete: () -> Unit = {},
) {
    var expanded by remember { mutableStateOf(false) }

    Box(modifier = modifier, contentAlignment = Alignment.TopEnd) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(CircleShape)
                .background(Color(0x8C0F172A))
                .clickable { expanded = true },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Outlined.MoreHoriz,
                contentDescription = "Actions",
                tint = Color.White,
                modifier = Modifier.size(16.dp),
            )
        }

        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier
                .background(menuGradient, RoundedCornerShape(SyncTokens.RadiusSm))
                .clip(RoundedCornerShape(SyncTokens.RadiusSm)),
            containerColor = Color.Transparent,
            shadowElevation = 8.dp,
        ) {
            if (showDownload) {
                ActionMenuItem(Icons.Outlined.Download, "Download") {
                    expanded = false
                    onDownload()
                }
            }
            if (showCopy) {
                ActionMenuItem(Icons.Outlined.ContentCopy, "Copy") {
                    expanded = false
                    onCopy()
                }
            }
            if (showPin) {
                ActionMenuItem(Icons.Outlined.PushPin, if (isPinned) "Unpin" else "Pin") {
                    expanded = false
                    onPin()
                }
            }
            if (showDelete) {
                ActionMenuItem(Icons.Outlined.Close, "Delete") {
                    expanded = false
                    onDelete()
                }
            }
        }
    }
}

@Composable
private fun ActionMenuItem(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
) {
    DropdownMenuItem(
        text = {
            Row(
                horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
                Text(
                    label,
                    color = Color.White,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        },
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
    )
}
