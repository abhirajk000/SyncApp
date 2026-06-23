package com.syncbridge.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.TextFields
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.clipboardDisplayText
import com.syncbridge.android.util.relativeTime

private val cardShape = RoundedCornerShape(SyncTokens.RadiusLg)

@Composable
fun AppCard(
    modifier: Modifier = Modifier,
    hero: Boolean = false,
    accentBorder: Color? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val border = accentBorder
        ?: if (hero) SyncTokens.Teal.copy(alpha = 0.22f) else null
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = cardShape,
        color = AppSurfaces.card(),
        shadowElevation = 1.dp,
        tonalElevation = 0.dp,
        border = androidx.compose.foundation.BorderStroke(
            1.dp,
            border ?: AppSurfaces.cardBorder(),
        ),
    ) {
        Column(Modifier.padding(SyncTokens.Space5), content = content)
    }
}

@Composable
fun GlassListRow(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(SyncTokens.RadiusLg)
    if (onClick != null) {
        Surface(
            onClick = onClick,
            shape = shape,
            color = AppSurfaces.card(),
            border = androidx.compose.foundation.BorderStroke(1.dp, AppSurfaces.cardBorder()),
            shadowElevation = 1.dp,
            modifier = modifier.fillMaxWidth(),
        ) {
            Column(
                Modifier.padding(horizontal = SyncTokens.Space5, vertical = SyncTokens.Space4),
                content = content,
            )
        }
    } else {
        SurfaceCard(modifier = modifier.fillMaxWidth(), shape = shape) {
            Column(
                Modifier.padding(horizontal = SyncTokens.Space5, vertical = SyncTokens.Space4),
                content = content,
            )
        }
    }
}

@Composable
fun AppSectionTitle(title: String) {
    Text(
        text = title.uppercase(),
        style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 1.2.sp),
        color = SyncTokens.SlateMuted,
        fontWeight = FontWeight.Bold,
        modifier = Modifier.padding(bottom = SyncTokens.Space2),
    )
}

@Composable
fun AppCardTitle(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurface,
    )
}

@Composable
fun AppCardDesc(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier.padding(top = SyncTokens.Space1, bottom = SyncTokens.Space3),
    )
}

@Composable
fun PrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
) {
    Button(
        onClick = onClick,
        enabled = enabled && !loading,
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp),
        shape = RoundedCornerShape(SyncTokens.RadiusMd),
        colors = ButtonDefaults.buttonColors(
            containerColor = SyncTokens.Teal,
            disabledContainerColor = SyncTokens.Teal.copy(0.4f),
        ),
        elevation = ButtonDefaults.buttonElevation(defaultElevation = 2.dp),
    ) {
        if (loading) {
            CircularProgressIndicator(
                modifier = Modifier.size(22.dp),
                strokeWidth = 2.dp,
                color = Color.White,
            )
        } else {
            Text(text, style = MaterialTheme.typography.titleSmall, color = Color.White)
        }
    }
}

@Composable
fun SettingsLinkRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(SyncTokens.RadiusMd))
            .clickable(onClick = onClick)
            .padding(vertical = SyncTokens.Space1),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space3),
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(SyncTokens.RadiusMd))
                .background(SyncTokens.Teal.copy(0.1f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = SyncTokens.Teal, modifier = Modifier.size(22.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(title, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodyLarge)
            Text(
                subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = SyncTokens.SlateMuted,
        )
    }
}

@Composable
fun LatestTextCard(
    entry: ClipboardEntry?,
    title: String = "Latest text",
    onCopy: () -> Unit,
) {
    LatestCardShell(
        empty = entry == null,
        accent = SyncTokens.Teal,
        icon = Icons.Outlined.TextFields,
        title = title,
        emptyMessage = "No text yet — copy on any device to sync here.",
    ) {
        if (entry != null) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(SyncTokens.RadiusMd))
                    .clickable(onClick = onCopy),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(SyncTokens.RadiusMd))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f))
                        .padding(SyncTokens.Space4),
                ) {
                    Text(
                        clipboardDisplayText(entry.content, 500),
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Medium,
                        maxLines = 8,
                        overflow = TextOverflow.Ellipsis,
                        lineHeight = 22.sp,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                }
                Row(
                    modifier = Modifier.padding(top = SyncTokens.Space3),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2),
                ) {
                    Text(
                        relativeTime(entry.createdAt),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text("·", color = SyncTokens.SlateMuted)
                    Text(
                        "Tap to copy",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = SyncTokens.Teal,
                    )
                }
            }
        }
    }
}

@Composable
fun LatestImageCard(
    entry: ClipboardEntry?,
    api: ApiClient,
    title: String = "Latest image",
    onCopy: () -> Unit,
) {
    LatestCardShell(
        empty = entry == null,
        accent = SyncTokens.Violet,
        icon = Icons.Outlined.Image,
        title = title,
        emptyMessage = "No image yet — screenshots and photos sync automatically.",
    ) {
        if (entry != null) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(SyncTokens.RadiusMd))
                    .clickable(onClick = onCopy),
            ) {
                ClipboardImageThumb(
                    entry = entry,
                    api = api,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(200.dp),
                    contentDescription = "Latest clipboard image",
                )
                Text(
                    "${relativeTime(entry.createdAt)} · Tap to copy",
                    style = MaterialTheme.typography.labelMedium,
                    color = SyncTokens.Violet,
                    modifier = Modifier.padding(top = SyncTokens.Space2),
                )
            }
        }
    }
}

@Composable
private fun LatestCardShell(
    empty: Boolean,
    accent: Color,
    icon: ImageVector,
    title: String,
    emptyMessage: String,
    content: @Composable ColumnScope.() -> Unit,
) {
    AppCard(accentBorder = if (empty) null else accent.copy(alpha = 0.22f)) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space3),
        ) {
            IconBadge(icon = icon, tint = if (empty) SyncTokens.SlateMuted else accent)
            Text(title, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
        }
        if (empty) {
            Text(
                emptyMessage,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = SyncTokens.Space3),
            )
        } else {
            Column(Modifier.padding(top = SyncTokens.Space3), content = content)
        }
    }
}

@Composable
fun EarlierImageRow(
    entry: ClipboardEntry,
    api: ApiClient,
    onCopy: () -> Unit,
) {
    GlassListRow(onClick = onCopy) {
        ClipboardImageThumb(
            entry = entry,
            api = api,
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp),
            contentDescription = "Clipboard image",
        )
        Text(
            "Image · ${relativeTime(entry.createdAt)} · Tap to copy",
            style = MaterialTheme.typography.labelMedium,
            color = SyncTokens.Violet,
            modifier = Modifier.padding(top = SyncTokens.Space2),
        )
    }
}

@Composable
fun EarlierTextRow(
    entry: ClipboardEntry,
    onCopy: () -> Unit,
) {
    GlassListRow(onClick = onCopy) {
        Text(
            clipboardDisplayText(entry.content, 280),
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            relativeTime(entry.createdAt),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = SyncTokens.Space1),
        )
    }
}
