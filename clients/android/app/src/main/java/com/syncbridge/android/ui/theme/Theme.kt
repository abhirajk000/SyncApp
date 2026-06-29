package com.syncbridge.android.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val LightColors = lightColorScheme(
    primary = SyncTokens.Teal,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFCCFBF1),
    secondary = SyncTokens.Indigo,
    secondaryContainer = Color(0xFFE0E7FF),
    background = SyncTokens.SlateBg,
    surface = Color.White,
    surfaceVariant = Color(0xFFEEF2F7),
    onSurface = SyncTokens.SlateText,
    onSurfaceVariant = SyncTokens.SlateSecondary,
    outline = SyncTokens.CardBorder,
    error = SyncTokens.Danger,
)

private val DarkColors = darkColorScheme(
    primary = SyncTokens.TealDark,
    onPrimary = Color(0xFF0F172A),
    primaryContainer = Color(0xFF134E4A),
    secondary = Color(0xFF818CF8),
    secondaryContainer = Color(0xFF312E81),
    background = Color(0xFF080D18),
    surface = Color(0xFF111827),
    surfaceVariant = Color(0xFF1A2332),
    onSurface = Color(0xFFF1F5F9),
    onSurfaceVariant = Color(0xFF94A3B8),
    outline = Color(0x14F8FAFC),
    error = Color(0xFFF87171),
)

@Composable
fun SyncBridgeTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val base = if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
            base.copy(
                primary = if (darkTheme) SyncTokens.TealDark else SyncTokens.Teal,
                secondary = if (darkTheme) Color(0xFF818CF8) else SyncTokens.Indigo,
                background = if (darkTheme) Color(0xFF080D18) else SyncTokens.SlateBg,
                surface = if (darkTheme) Color(0xFF111827) else Color.White,
                outline = if (darkTheme) Color(0xFF1E293B) else SyncTokens.CardBorder,
            )
        }
        darkTheme -> DarkColors
        else -> LightColors
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = syncTypography(),
        shapes = SyncShapes,
        content = content,
    )
}
