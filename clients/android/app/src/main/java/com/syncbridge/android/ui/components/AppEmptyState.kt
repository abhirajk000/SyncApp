package com.syncbridge.android.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp
import androidx.compose.material3.Text
import com.syncbridge.android.ui.theme.SyncTokens

@Composable
fun AppEmptyState(
    title: String,
    description: String,
    illustration: EmptyArt = EmptyArt.Inbox,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
) {
    AppCard(hero = true) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = SyncTokens.Space6),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4),
        ) {
            EmptyIllustration(variant = illustration)
            Text(
                title,
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center,
                color = SyncTokens.SlateText,
            )
            Text(
                description,
                fontSize = 14.sp,
                color = SyncTokens.SlateSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = SyncTokens.Space4),
                lineHeight = 22.sp,
            )
            if (actionLabel != null && onAction != null) {
                PrimaryButton(text = actionLabel, onClick = onAction, modifier = Modifier.padding(top = SyncTokens.Space2))
            }
        }
    }
}
