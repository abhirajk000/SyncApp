package com.syncbridge.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.syncbridge.android.ui.theme.SyncTokens

@Composable
fun AppCard(
    modifier: Modifier = Modifier,
    hero: Boolean = false,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(SyncTokens.RadiusLg)
    if (hero) {
        Column(
            modifier = modifier
                .fillMaxWidth()
                .shadow(12.dp, shape, ambientColor = SyncTokens.Teal.copy(0.15f))
                .clip(shape)
                .background(
                    Brush.linearGradient(
                        listOf(
                            SyncTokens.Teal.copy(alpha = 0.14f),
                            SyncTokens.Indigo.copy(alpha = 0.08f),
                        ),
                    ),
                )
                .border(1.dp, SyncTokens.Teal.copy(0.25f), shape)
                .padding(SyncTokens.Space6),
            content = content,
        )
    } else {
        GlassSurface(modifier = modifier.fillMaxWidth(), shape = shape) {
            Column(Modifier.padding(SyncTokens.Space6), content = content)
        }
    }
}

@Composable
fun GlassListRow(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(SyncTokens.RadiusMd)
    val rowModifier = modifier.fillMaxWidth()
    if (onClick != null) {
        androidx.compose.material3.Surface(
            onClick = onClick,
            shape = shape,
            color = GlassColors.surface(),
            border = androidx.compose.foundation.BorderStroke(1.dp, GlassColors.border()),
            shadowElevation = 2.dp,
            modifier = rowModifier,
        ) {
            Column(Modifier.padding(SyncTokens.Space4), content = content)
        }
    } else {
        GlassSurface(modifier = rowModifier, shape = shape, elevation = 2.dp) {
            Column(Modifier.padding(SyncTokens.Space4), content = content)
        }
    }
}

@Composable
fun AppSectionTitle(title: String) {
    Text(
        text = title.uppercase(),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        letterSpacing = MaterialTheme.typography.labelSmall.letterSpacing * 1.5f,
        modifier = Modifier.padding(bottom = SyncTokens.Space3),
    )
}

@Composable
fun AppCardTitle(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleMedium,
        color = MaterialTheme.colorScheme.onSurface,
    )
}

@Composable
fun AppCardDesc(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier.padding(top = SyncTokens.Space1, bottom = SyncTokens.Space4),
    )
}
