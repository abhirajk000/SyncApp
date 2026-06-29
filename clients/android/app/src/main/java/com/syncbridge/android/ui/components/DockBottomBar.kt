package com.syncbridge.android.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CloudUpload
import androidx.compose.material.icons.outlined.ContentPaste
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.WifiTethering
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
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
    val haptic = LocalHapticFeedback.current
    val clipboardSelected = current == MainTab.Clipboard
    val clipboardScale by animateFloatAsState(
        targetValue = if (clipboardSelected) 1.06f else 1f,
        animationSpec = spring(dampingRatio = 0.72f, stiffness = 380f),
        label = "clipboardFabScale",
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = SyncTokens.Space4, vertical = SyncTokens.Space3),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(SyncTokens.DockHeight)
                .align(Alignment.BottomCenter)
                .shadow(20.dp, BottomDockBarShape, clip = false, ambientColor = Color.Black.copy(0.42f))
                .clip(BottomDockBarShape)
                .background(
                    Brush.verticalGradient(
                        listOf(AppSurfaces.dockFillTop(), AppSurfaces.dockFillBottom()),
                    ),
                )
                .padding(horizontal = 14.dp, vertical = 10.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxSize(),
                verticalAlignment = Alignment.Bottom,
            ) {
                Row(
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.Bottom,
                ) {
                    DockNavItem(MainTab.CloudSend, Icons.Outlined.CloudUpload, current, onNavigate, haptic)
                    DockNavItem(MainTab.LocalSend, Icons.Outlined.WifiTethering, current, onNavigate, haptic)
                }
                Spacer(Modifier.width(76.dp))
                Row(
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.Bottom,
                ) {
                    DockNavItem(MainTab.Files, Icons.Outlined.Folder, current, onNavigate, haptic)
                    DockNavItem(MainTab.Settings, Icons.Outlined.Settings, current, onNavigate, haptic)
                }
            }
        }

        Box(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .offset(y = (-10).dp)
                .scale(clipboardScale)
                .size(64.dp)
                .shadow(
                    elevation = if (clipboardSelected) 16.dp else 12.dp,
                    shape = CircleShape,
                    spotColor = SyncTokens.Teal.copy(alpha = if (clipboardSelected) 0.55f else 0.4f),
                )
                .clip(CircleShape)
                .background(SyncTokens.Teal)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) {
                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    onNavigate(MainTab.Clipboard)
                },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Outlined.ContentPaste,
                contentDescription = "Clipboard",
                tint = Color.White,
                modifier = Modifier.size(28.dp),
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
    haptic: androidx.compose.ui.hapticfeedback.HapticFeedback,
) {
    val selected = current == tab

    Surface(
        onClick = {
            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
            onNavigate(tab)
        },
        shape = CircleShape,
        color = if (selected) SyncTokens.DockActiveBg else Color.Transparent,
        border = if (selected) BorderStroke(1.dp, SyncTokens.DockActiveBorder) else null,
        shadowElevation = if (selected) 3.dp else 0.dp,
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
                fontSize = 8.sp,
                fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                color = if (selected) SyncTokens.DockActiveGreen else SyncTokens.DockInactive,
                maxLines = 1,
                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
            )
        }
    }
}
