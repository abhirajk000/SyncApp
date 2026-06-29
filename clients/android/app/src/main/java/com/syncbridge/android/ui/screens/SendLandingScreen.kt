package com.syncbridge.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Cloud
import androidx.compose.material.icons.outlined.Wifi
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.syncbridge.android.ui.components.AppCardDesc
import com.syncbridge.android.ui.components.AppCardTitle
import com.syncbridge.android.ui.components.GhostButton
import com.syncbridge.android.ui.theme.SyncTokens

@Composable
fun SendLandingScreen(
    onCloud: () -> Unit,
    onWifi: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(
                start = SyncTokens.Space4,
                end = SyncTokens.Space4,
                top = SyncTokens.Space4,
                bottom = SyncTokens.DockScrollPadding,
            ),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
    ) {
        Text(
            "Send",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        Text(
            "Choose how you want to transfer files.",
            style = MaterialTheme.typography.bodyMedium,
            color = SyncTokens.TextMuted,
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
        ) {
            SendModeCard(
                title = "Cloud Send",
                description = "Text, images, and files via your SyncBridge server.",
                icon = Icons.Outlined.Cloud,
                gradient = listOf(SyncTokens.Primary, SyncTokens.Secondary),
                onClick = onCloud,
                modifier = Modifier.weight(1f),
            )
            SendModeCard(
                title = "Local Send",
                description = "Direct Wi‑Fi — no cloud upload.",
                icon = Icons.Outlined.Wifi,
                gradient = listOf(SyncTokens.Indigo, SyncTokens.Violet),
                onClick = onWifi,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun SendModeCard(
    title: String,
    description: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    gradient: List<Color>,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(SyncTokens.RadiusCard))
            .background(com.syncbridge.android.ui.components.AppSurfaces.card())
            .border(1.dp, com.syncbridge.android.ui.components.AppSurfaces.cardStroke(), RoundedCornerShape(SyncTokens.RadiusCard))
            .clickable(onClick = onClick)
            .padding(SyncTokens.Space5),
        verticalArrangement = Arrangement.spacedBy(SyncTokens.Space3),
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(RoundedCornerShape(SyncTokens.RadiusLg))
                .background(Brush.linearGradient(gradient)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = Color.White)
        }
        AppCardTitle(title)
        AppCardDesc(description)
    }
}
