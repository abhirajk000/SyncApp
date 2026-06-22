package com.syncbridge.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
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
    if (hero) {
        Box(
            modifier = modifier
                .fillMaxWidth()
                .shadow(12.dp, RoundedCornerShape(SyncTokens.RadiusLg), ambientColor = SyncTokens.Teal.copy(0.15f))
                .clip(RoundedCornerShape(SyncTokens.RadiusLg))
                .background(
                    Brush.linearGradient(
                        listOf(
                            SyncTokens.Teal.copy(alpha = 0.12f),
                            SyncTokens.Indigo.copy(alpha = 0.06f),
                        ),
                    ),
                )
                .border(1.dp, SyncTokens.Teal.copy(0.2f), RoundedCornerShape(SyncTokens.RadiusLg))
                .padding(SyncTokens.Space6),
        ) {
            Column(content = content)
        }
    } else {
        Card(
            modifier = modifier.fillMaxWidth(),
            shape = RoundedCornerShape(SyncTokens.RadiusLg),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
            content = { Column(Modifier.padding(SyncTokens.Space6), content = content) },
        )
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
