package com.syncbridge.android.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.outlined.ContentPaste
import androidx.compose.material.icons.outlined.Devices
import androidx.compose.material.icons.outlined.Folder
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.syncbridge.android.ui.theme.SyncTokens

enum class EmptyArt { Clipboard, Files, Send, Devices, Pinned, Inbox }

fun Modifier.floatingCardShadow(
    shape: Shape,
    elevation: Dp = 12.dp,
    hero: Boolean = false,
): Modifier = shadow(
    elevation = elevation,
    shape = shape,
    ambientColor = Color.Black.copy(alpha = if (hero) 0.14f else 0.08f),
    spotColor = if (hero) SyncTokens.Teal.copy(0.18f) else SyncTokens.Indigo.copy(0.10f),
)

fun Modifier.pressableScale(
    interactionSource: MutableInteractionSource? = null,
    pressedScale: Float = 0.97f,
): Modifier = composed {
    val source = interactionSource ?: remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    scale(if (pressed) pressedScale else 1f)
}

@Composable
fun rememberOrbDrift(): Pair<Float, Float> {
    val transition = rememberInfiniteTransition(label = "orb-drift")
    val x by transition.animateFloat(
        initialValue = 0f,
        targetValue = 24f,
        animationSpec = infiniteRepeatable(tween(22000, easing = LinearEasing), RepeatMode.Reverse),
        label = "orb-x",
    )
    val y by transition.animateFloat(
        initialValue = 0f,
        targetValue = -16f,
        animationSpec = infiniteRepeatable(tween(26000, easing = LinearEasing), RepeatMode.Reverse),
        label = "orb-y",
    )
    return x to y
}

@Composable
fun EmptyIllustration(
    variant: EmptyArt = EmptyArt.Inbox,
    modifier: Modifier = Modifier,
) {
    val icon: ImageVector = when (variant) {
        EmptyArt.Clipboard -> Icons.Outlined.ContentPaste
        EmptyArt.Files -> Icons.Outlined.Folder
        EmptyArt.Send -> Icons.AutoMirrored.Outlined.Send
        EmptyArt.Devices -> Icons.Outlined.Devices
        EmptyArt.Pinned -> Icons.Outlined.PushPin
        EmptyArt.Inbox -> Icons.Outlined.Inbox
    }
    val shape = RoundedCornerShape(SyncTokens.RadiusCard)
    Box(
        modifier = modifier
            .size(88.dp)
            .floatingCardShadow(shape, hero = true)
            .clip(shape)
            .background(
                Brush.linearGradient(
                    listOf(SyncTokens.Teal.copy(0.14f), SyncTokens.Indigo.copy(0.10f)),
                ),
            )
            .border(1.dp, AppSurfaces.cardStroke(), shape),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = SyncTokens.Teal, modifier = Modifier.size(36.dp))
    }
}

@Composable
fun ImagePlaceholder(
    modifier: Modifier = Modifier,
    height: Dp = 120.dp,
) {
    val shape = RoundedCornerShape(SyncTokens.RadiusMd)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .clip(shape)
            .background(
                Brush.linearGradient(
                    listOf(
                        SyncTokens.SlateMuted.copy(0.12f),
                        Color.White.copy(0.35f),
                        SyncTokens.SlateMuted.copy(0.12f),
                    ),
                ),
            )
            .border(1.dp, AppSurfaces.cardStroke(), shape),
    )
}
