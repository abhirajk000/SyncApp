package com.syncbridge.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.syncbridge.android.ui.theme.SyncTokens

object GlassColors {
    @Composable
    fun surface(): Color =
        if (isSystemInDarkTheme()) Color(0xB7111827) else Color(0xB8FFFFFF)

    @Composable
    fun border(): Color =
        if (isSystemInDarkTheme()) Color(0x1AF8FAFC) else Color(0xD9FFFFFF)

    @Composable
    fun highlight(): Color =
        if (isSystemInDarkTheme()) Color(0x14F8FAFC) else Color(0xE6FFFFFF)

    @Composable
    fun dock(): Color =
        if (isSystemInDarkTheme()) Color(0xE61C2232) else Color(0xEBFFFFFF)
}

@Composable
fun LiquidBackground(modifier: Modifier = Modifier) {
    val isDark = isSystemInDarkTheme()
    val base = if (isDark) Color(0xFF080D18) else SyncTokens.SlateBg
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(base),
    ) {
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            SyncTokens.Teal.copy(if (isDark) 0.14f else 0.18f),
                            Color.Transparent,
                        ),
                        radius = 900f,
                    ),
                ),
        )
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            SyncTokens.Indigo.copy(if (isDark) 0.10f else 0.12f),
                            Color.Transparent,
                        ),
                        center = androidx.compose.ui.geometry.Offset(1200f, 800f),
                        radius = 700f,
                    ),
                ),
        )
    }
}

@Composable
fun GlassSurface(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(SyncTokens.RadiusLg),
    elevation: Dp = 4.dp,
    content: @Composable BoxScope.() -> Unit,
) {
    Box(
        modifier = modifier
            .shadow(elevation, shape, ambientColor = Color.Black.copy(0.06f))
            .clip(shape)
            .background(GlassColors.surface())
            .border(1.dp, GlassColors.border(), shape),
        content = content,
    )
}
