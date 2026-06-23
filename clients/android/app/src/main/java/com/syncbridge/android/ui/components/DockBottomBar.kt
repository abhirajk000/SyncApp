package com.syncbridge.android.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.outlined.ContentPaste
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.syncbridge.android.ui.MainTab
import com.syncbridge.android.ui.theme.SyncTokens

@Composable
fun DockBottomBar(
    current: MainTab,
    onNavigate: (MainTab) -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = SyncTokens.Space4, vertical = SyncTokens.Space3),
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .height(SyncTokens.DockHeight)
                .align(Alignment.BottomCenter),
            shape = RoundedCornerShape(999.dp),
            color = AppSurfaces.dock(),
            shadowElevation = 8.dp,
            tonalElevation = 0.dp,
            border = BorderStroke(1.dp, AppSurfaces.cardBorder()),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = SyncTokens.Space2),
                verticalAlignment = Alignment.Bottom,
            ) {
                Row(
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.Bottom,
                ) {
                    DockNavItem(MainTab.Clipboard, Icons.Outlined.ContentPaste, current, onNavigate)
                    DockNavItem(MainTab.Pinned, Icons.Outlined.PushPin, current, onNavigate)
                }
                Spacer(Modifier.width(56.dp))
                Row(
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.Bottom,
                ) {
                    DockNavItem(MainTab.Files, Icons.Outlined.Folder, current, onNavigate)
                    DockNavItem(MainTab.Settings, Icons.Outlined.Settings, current, onNavigate)
                }
            }
        }

        Box(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .offset(y = (-4).dp)
                .size(60.dp)
                .clip(CircleShape)
                .background(
                    Brush.horizontalGradient(
                        listOf(Color(0xFF3B82F6), Color(0xFF6366F1), Color(0xFF7C3AED)),
                    ),
                )
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) { onNavigate(MainTab.Send) },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.AutoMirrored.Outlined.Send,
                contentDescription = "Send",
                tint = Color.White,
                modifier = Modifier.size(24.dp),
            )
        }
    }
}

@Composable
private fun DockNavItem(
    tab: MainTab,
    icon: ImageVector,
    current: MainTab,
    onNavigate: (MainTab) -> Unit,
) {
    val selected = current == tab

    Surface(
        onClick = { onNavigate(tab) },
        shape = RoundedCornerShape(999.dp),
        color = if (selected) SyncTokens.DockActiveBg else Color.Transparent,
        border = if (selected) BorderStroke(1.dp, SyncTokens.DockActiveBorder) else null,
        shadowElevation = if (selected) 2.dp else 0.dp,
        modifier = Modifier
            .width(72.dp)
            .height(52.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Icon(
                icon,
                contentDescription = tab.label,
                tint = if (selected) SyncTokens.DockActiveGreen else SyncTokens.DockInactive,
                modifier = Modifier.size(22.dp),
            )
            Text(
                tab.label,
                fontSize = 9.sp,
                fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                color = if (selected) SyncTokens.DockActiveGreen else SyncTokens.DockInactive,
                maxLines = 1,
                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
            )
        }
    }
}
