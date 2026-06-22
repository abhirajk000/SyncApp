package com.syncbridge.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.syncbridge.android.ui.theme.SyncTokens

@Composable
fun AppEmptyState(
    icon: ImageVector = Icons.Outlined.Inbox,
    title: String,
    description: String,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(SyncTokens.Space8),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
    ) {
        Box(
            modifier = Modifier
                .size(72.dp)
                .background(
                    Brush.linearGradient(
                        listOf(SyncTokens.Teal.copy(0.12f), SyncTokens.Indigo.copy(0.06f)),
                    ),
                    RoundedCornerShape(SyncTokens.RadiusLg),
                )
                .border(1.dp, SyncTokens.Teal.copy(0.15f), RoundedCornerShape(SyncTokens.RadiusLg)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, null, modifier = Modifier.size(32.dp), tint = SyncTokens.Teal)
        }
        Text(title, style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
        Text(
            description,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = SyncTokens.Space6),
        )
        if (actionLabel != null && onAction != null) {
            Button(
                onClick = onAction,
                colors = ButtonDefaults.buttonColors(containerColor = SyncTokens.Teal),
                shape = RoundedCornerShape(SyncTokens.RadiusMd),
            ) { Text(actionLabel) }
        }
    }
}
