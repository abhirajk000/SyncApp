package com.syncbridge.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.syncbridge.android.ui.theme.SyncTokens

/** Solid surface colors — no glass / blur. */
object AppSurfaces {
    @Composable
    fun pageBackground(): Color = MaterialTheme.colorScheme.background

    @Composable
    fun card(): Color = MaterialTheme.colorScheme.surface

    @Composable
    fun cardBorder(): Color =
        if (isSystemInDarkTheme()) Color(0xFF1E293B) else SyncTokens.CardBorder

    @Composable
    fun dock(): Color =
        if (isSystemInDarkTheme()) Color(0xFF111827) else Color.White
}

/** @deprecated Use [AppSurfaces] */
object GlassColors {
    @Composable fun surface(): Color = AppSurfaces.card()
    @Composable fun border(): Color = AppSurfaces.cardBorder()
    @Composable fun highlight(): Color = AppSurfaces.card()
    @Composable fun dock(): Color = AppSurfaces.dock()
}

@Composable
fun AppBackground(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(AppSurfaces.pageBackground()),
    )
}

/** @deprecated Use [AppBackground] */
@Composable
fun LiquidBackground(modifier: Modifier = Modifier) = AppBackground(modifier)

@Composable
fun SurfaceCard(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(SyncTokens.RadiusLg),
    borderColor: Color? = null,
    elevation: Dp = 1.dp,
    content: @Composable BoxScope.() -> Unit,
) {
    val border = borderColor ?: AppSurfaces.cardBorder()
    Box(
        modifier = modifier
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
    shape: Shape = RoundedCornerShape(SyncTokens.RadiusLg),
    elevation: Dp = 1.dp,
    content: @Composable BoxScope.() -> Unit,
) = SurfaceCard(modifier, shape, elevation = elevation, content = content)
