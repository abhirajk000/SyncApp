package com.syncbridge.android.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

/**
 * SyncBridge global design tokens.
 * Source of truth: shared/theme/tokens.json · shared/design-system.md
 */
object SyncTokens {
    // Colors — light mode (dark overrides in Theme.kt)
    val Primary = androidx.compose.ui.graphics.Color(0xFF0D9488)
    val PrimaryHover = androidx.compose.ui.graphics.Color(0xFF0F766E)
    val Teal = Primary
    val TealLight = androidx.compose.ui.graphics.Color(0xFF14B8A6)
    val TealDark = androidx.compose.ui.graphics.Color(0xFF2DD4BF)
    val Secondary = androidx.compose.ui.graphics.Color(0xFF4F46E5)
    val Indigo = Secondary
    val Success = androidx.compose.ui.graphics.Color(0xFF059669)
    val Warning = androidx.compose.ui.graphics.Color(0xFFD97706)
    val Danger = androidx.compose.ui.graphics.Color(0xFFDC2626)
    val Background = androidx.compose.ui.graphics.Color(0xFFF4F7FB)
    val SlateBg = Background
    val Surface = androidx.compose.ui.graphics.Color(0xB8FFFFFF)
    val TextPrimary = androidx.compose.ui.graphics.Color(0xFF0C1222)
    val SlateText = TextPrimary
    val TextSecondary = androidx.compose.ui.graphics.Color(0xFF5C6B82)
    val SlateSecondary = TextSecondary
    val TextMuted = androidx.compose.ui.graphics.Color(0xFF8B9BB5)
    val SlateMuted = TextMuted
    val Border = androidx.compose.ui.graphics.Color(0x140F172A)
    val CardBorder = androidx.compose.ui.graphics.Color(0xFFE2E8F0)
    val CardBorderSubtle = androidx.compose.ui.graphics.Color(0xFFE8EDF4)
    val Accent = androidx.compose.ui.graphics.Color(0xFF7C3AED)
    val Violet = Accent
    val DockInactive = androidx.compose.ui.graphics.Color(0xFF94A3B8)
    val DockActiveGreen = androidx.compose.ui.graphics.Color(0xFF15803D)
    val DockActiveBg = androidx.compose.ui.graphics.Color(0xE6BBF7D0)
    val DockActiveBorder = androidx.compose.ui.graphics.Color(0x8C4ADE80)

    // Spacing — 8pt grid only
    val Space1 = 4.dp
    val Space2 = 8.dp
    val Space3 = 12.dp
    val Space4 = 16.dp
    val Space5 = 20.dp
    val Space6 = 24.dp
    val Space8 = 32.dp
    val Space10 = 40.dp
    val Space12 = 48.dp

    // Layout
    val HeaderHeight = 64.dp
    val DockHeight = 66.dp
    /** Scroll content bottom inset — Scaffold bottomBar already reserves [DockHeight]. */
    val DockScrollPadding = Space10
    val BottomNavHeight = 72.dp

    // Radius — One UI containers (24–32dp)
    val RadiusSm = 8.dp
    val RadiusMd = 14.dp
    val RadiusInput = 18.dp
    val RadiusButton = 20.dp
    val RadiusLg = 20.dp
    val RadiusContainerInner = 20.dp
    val RadiusContainerSm = 24.dp
    val RadiusCard = 28.dp
    val RadiusContainer = 28.dp
    val RadiusDialog = 32.dp
    val RadiusContainerLg = 32.dp
    val RadiusXl = 32.dp
    val RadiusChip = 9999.dp

    // Shadows (elevation dp approximations of CSS shadows)
    val ShadowSmall = 2.dp
    val ShadowMedium = 8.dp
    val ShadowLarge = 16.dp
    val ShadowFloating = 24.dp

    // Icon sizes
    val IconSm = 16.dp
    val IconMd = 20.dp
    val IconBase = 24.dp
    val IconLg = 28.dp
    val IconXl = 32.dp
    val Icon2xl = 40.dp

    // Transfer badge colors
    val BadgeCloudBg = androidx.compose.ui.graphics.Color(0x1F4F46E5)
    val BadgeCloudFg = Secondary
    val BadgeCloudBorder = androidx.compose.ui.graphics.Color(0x334F46E5)
    val BadgeLanBg = androidx.compose.ui.graphics.Color(0x1F059669)
    val BadgeLanFg = Success
    val BadgeLanBorder = androidx.compose.ui.graphics.Color(0x40059669)
    val BadgeRtcBg = androidx.compose.ui.graphics.Color(0x1F7C3AED)
    val BadgeRtcFg = Accent
    val BadgeRtcBorder = androidx.compose.ui.graphics.Color(0x337C3AED)

    // Dock FAB gradient
    val FabGradientStart = androidx.compose.ui.graphics.Color(0xFF4F46E5)
    val FabGradientMid = Secondary
    val FabGradientEnd = Accent

    // Animation durations (ms)
    const val DurationFast = 150
    const val DurationNormal = 250
    const val DurationSlow = 350
    const val DurationSlower = 500
}

val SyncShapes = Shapes(
    extraSmall = RoundedCornerShape(SyncTokens.RadiusSm),
    small = RoundedCornerShape(SyncTokens.RadiusSm),
    medium = RoundedCornerShape(SyncTokens.RadiusMd),
    large = RoundedCornerShape(SyncTokens.RadiusButton),
    extraLarge = RoundedCornerShape(SyncTokens.RadiusCard),
)
