package com.syncbridge.android.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

object SyncTokens {
    val Teal = androidx.compose.ui.graphics.Color(0xFF0D9488)
    val TealLight = androidx.compose.ui.graphics.Color(0xFF14B8A6)
    val TealDark = androidx.compose.ui.graphics.Color(0xFF2DD4BF)
    val Indigo = androidx.compose.ui.graphics.Color(0xFF4F46E5)
    val Success = androidx.compose.ui.graphics.Color(0xFF059669)
    val Danger = androidx.compose.ui.graphics.Color(0xFFDC2626)
    val SlateBg = androidx.compose.ui.graphics.Color(0xFFF4F7FB)
    val SlateText = androidx.compose.ui.graphics.Color(0xFF0C1222)
    val SlateSecondary = androidx.compose.ui.graphics.Color(0xFF5C6B82)
    val SlateMuted = androidx.compose.ui.graphics.Color(0xFF8B9BB5)
    val CardBorder = androidx.compose.ui.graphics.Color(0xFFE2E8F0)
    val CardBorderSubtle = androidx.compose.ui.graphics.Color(0xFFE8EDF4)
    val Violet = androidx.compose.ui.graphics.Color(0xFF7C3AED)
    val DockInactive = androidx.compose.ui.graphics.Color(0xFF94A3B8)
    val DockActiveGreen = androidx.compose.ui.graphics.Color(0xFF15803D)
    val DockActiveBg = androidx.compose.ui.graphics.Color(0xE6BBF7D0)
    val DockActiveBorder = androidx.compose.ui.graphics.Color(0x8C4ADE80)

    val Space1 = 4.dp
    val Space2 = 8.dp
    val Space3 = 12.dp
    val Space4 = 16.dp
    val Space5 = 20.dp
    val Space6 = 24.dp
    val Space8 = 32.dp
    val Space10 = 40.dp
    val HeaderHeight = 64.dp
    val DockHeight = 66.dp

    val RadiusSm = 8.dp
    val RadiusMd = 14.dp
    val RadiusLg = 20.dp
    val RadiusXl = 28.dp
}

val SyncShapes = Shapes(
    extraSmall = RoundedCornerShape(SyncTokens.RadiusSm),
    small = RoundedCornerShape(SyncTokens.RadiusSm),
    medium = RoundedCornerShape(SyncTokens.RadiusMd),
    large = RoundedCornerShape(SyncTokens.RadiusLg),
    extraLarge = RoundedCornerShape(SyncTokens.RadiusXl),
)
