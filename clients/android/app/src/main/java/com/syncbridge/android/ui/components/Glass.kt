package com.syncbridge.android.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.syncbridge.android.ui.theme.SyncTokens

/** Glass / liquid surfaces matching web tokens.css */
object AppSurfaces {
    @Composable
    fun pageBackground(): Color =
        if (isSystemInDarkTheme()) Color(0xFF080D18) else SyncTokens.SlateBg

    @Composable
    fun card(): Color =
        if (isSystemInDarkTheme()) Color(0xB7111827) else Color(0xB8FFFFFF)

    @Composable
    fun cardBorder(): Color =
        if (isSystemInDarkTheme()) Color(0x14F8FAFC) else Color(0x14FFFFFF)

    @Composable
    fun cardStroke(): Color =
        if (isSystemInDarkTheme()) Color(0x14F8FAFC) else Color(0x140F172A)

    @Composable
    fun dockFillTop(): Color =
        if (isSystemInDarkTheme()) Color(0xE01C2232) else Color(0xEBFFFFFF)

    @Composable
    fun dockFillBottom(): Color =
        if (isSystemInDarkTheme()) Color(0xF50C101C) else Color(0xE0F8FAFC)

    @Composable
    fun dockStroke(): Color =
        if (isSystemInDarkTheme()) Color(0x1AFFFFFF) else Color(0x24FFFFFF)
}

/** @deprecated Use [AppSurfaces] */
object GlassColors {
    @Composable fun surface(): Color = AppSurfaces.card()
    @Composable fun border(): Color = AppSurfaces.cardStroke()
    @Composable fun highlight(): Color = AppSurfaces.card()
    @Composable fun dock(): Color = AppSurfaces.dockFillTop()
}

@Composable
fun AppBackground(modifier: Modifier = Modifier) {
    val dark = isSystemInDarkTheme()
    val (driftX, driftY) = rememberOrbDrift()
    val transition = rememberInfiniteTransition(label = "orb-pulse")
    val pulse by transition.animateFloat(
        initialValue = 0.92f,
        targetValue = 1.05f,
        animationSpec = infiniteRepeatable(tween(18000, easing = LinearEasing), RepeatMode.Reverse),
        label = "pulse",
    )
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(AppSurfaces.pageBackground()),
    ) {
        Box(
            Modifier
                .fillMaxSize()
                .offset(x = (driftX * 0.3f).dp, y = (driftY * 0.2f).dp)
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            SyncTokens.Teal.copy(alpha = if (dark) 0.10f else 0.14f),
                            Color.Transparent,
                        ),
                        center = Offset(0.08f, 0.02f),
                        radius = 900f * pulse,
                    ),
                ),
        )
        Box(
            Modifier
                .fillMaxSize()
                .offset(x = (-driftX * 0.25f).dp, y = (-driftY * 0.15f).dp)
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            SyncTokens.Indigo.copy(alpha = if (dark) 0.08f else 0.10f),
                            Color.Transparent,
                        ),
                        center = Offset(0.92f, 0.95f),
                        radius = 700f * pulse,
                    ),
                ),
        )
        // Soft accent orb — top right
        Box(
            Modifier
                .fillMaxSize()
                .blur(80.dp)
                .offset(x = (driftX * 0.15f).dp, y = (driftY * 0.1f).dp)
                .background(
                    Brush.radialGradient(
                        colors = listOf(SyncTokens.Accent.copy(alpha = 0.06f), Color.Transparent),
                        center = Offset(0.85f, 0.12f),
                        radius = 500f,
                    ),
                ),
        )
    }
}

/** @deprecated Use [AppBackground] */
@Composable
fun LiquidBackground(modifier: Modifier = Modifier) = AppBackground(modifier)

@Composable
fun SurfaceCard(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(SyncTokens.RadiusCard),
    borderColor: Color? = null,
    elevation: Dp = 0.dp,
    content: @Composable BoxScope.() -> Unit,
) {
    val border = borderColor ?: AppSurfaces.cardStroke()
    Box(
        modifier = modifier
            .floatingCardShadow(shape)
            .clip(shape)
            .background(AppSurfaces.card())
            .border(1.dp, border, shape),
        content = content,
    )
}

/** @deprecated Use [SurfaceCard] */
@Composable
fun GlassSurface(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(SyncTokens.RadiusCard),
    elevation: Dp = 0.dp,
    content: @Composable BoxScope.() -> Unit,
) = SurfaceCard(modifier, shape, elevation = elevation, content = content)
