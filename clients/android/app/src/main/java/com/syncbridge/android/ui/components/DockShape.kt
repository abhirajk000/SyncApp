package com.syncbridge.android.ui.components

import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.graphics.Shape

/** Web ds-dock-nav curved bar (viewBox 0 0 420 64). */
object BottomDockBarShape : Shape {
    override fun createOutline(
        size: Size,
        layoutDirection: LayoutDirection,
        density: Density,
    ): Outline {
        val sx = size.width / 420f
        val sy = size.height / 64f
        fun px(x: Float) = x * sx
        fun py(y: Float) = y * sy

        val path = Path().apply {
            moveTo(px(36f), py(64f))
            cubicTo(px(18f), py(64f), px(4f), py(50f), px(4f), py(32f))
            lineTo(px(4f), py(22f))
            cubicTo(px(4f), py(10f), px(14f), py(0f), px(26f), py(0f))
            lineTo(px(148f), py(0f))
            cubicTo(px(162f), py(0f), px(172f), py(3f), px(178f), py(8f))
            cubicTo(px(186f), py(16f), px(196f), py(21f), px(210f), py(24.5f))
            cubicTo(px(224f), py(21f), px(234f), py(16f), px(242f), py(8f))
            cubicTo(px(248f), py(3f), px(258f), py(0f), px(272f), py(0f))
            lineTo(px(394f), py(0f))
            cubicTo(px(406f), py(0f), px(416f), py(10f), px(416f), py(22f))
            lineTo(px(416f), py(32f))
            cubicTo(px(416f), py(50f), px(402f), py(64f), px(384f), py(64f))
            lineTo(px(36f), py(64f))
            close()
        }
        return Outline.Generic(path)
    }
}
