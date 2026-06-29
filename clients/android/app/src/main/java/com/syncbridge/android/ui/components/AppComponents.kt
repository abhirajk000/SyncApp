package com.syncbridge.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.TextFields
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.syncbridge.android.data.ApiClient
import com.syncbridge.android.data.ClipboardEntry
import com.syncbridge.android.ui.theme.SyncTokens
import com.syncbridge.android.util.clipboardDisplayText
import com.syncbridge.android.util.isImageContentType
import com.syncbridge.android.util.relativeTime

private val cardShape = RoundedCornerShape(SyncTokens.RadiusContainerLg)

@Composable
fun AppCard(
    modifier: Modifier = Modifier,
    hero: Boolean = false,
    accentBorder: Color? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val border = accentBorder
        ?: if (hero) SyncTokens.Teal.copy(alpha = 0.22f) else null
    val shape = cardShape
    Box(
        modifier = modifier
            .fillMaxWidth()
            .floatingCardShadow(shape, hero = hero)
            .clip(shape)
            .background(
                if (hero) {
                    Brush.linearGradient(
                        listOf(
                            SyncTokens.Teal.copy(0.12f),
                            SyncTokens.Indigo.copy(0.08f),
                        ),
                    )
                } else {
                    Brush.linearGradient(listOf(AppSurfaces.card(), AppSurfaces.card()))
                },
            )
            .border(1.dp, border ?: AppSurfaces.cardStroke(), shape),
    ) {
        Column(Modifier.padding(SyncTokens.Space6), content = content)
    }
}

@Composable
fun GlassListRow(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(SyncTokens.RadiusContainer)
    if (onClick != null) {
        val interaction = remember { MutableInteractionSource() }
        Box(
            modifier = modifier
                .fillMaxWidth()
                .floatingCardShadow(shape)
                .clip(shape)
                .background(AppSurfaces.card())
                .border(1.dp, AppSurfaces.cardStroke(), shape)
                .pressableScale(interaction)
                .clickable(interactionSource = interaction, indication = null, onClick = onClick),
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
        modifier = Modifier.padding(bottom = SyncTokens.Space2, start = SyncTokens.Space1),
    )
}

/** One UI — multiple rows inside a single large rounded container. */
@Composable
fun ContainerGroup(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(SyncTokens.RadiusContainerLg)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .floatingCardShadow(shape)
            .clip(shape)
            .background(AppSurfaces.card())
            .border(1.dp, AppSurfaces.cardStroke(), shape)
            .padding(vertical = SyncTokens.Space2),
        content = content,
    )
}

@Composable
fun ContainerGroupItem(
    showDivider: Boolean = true,
    content: @Composable RowScope.() -> Unit,
) {
    Column(Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = SyncTokens.Space5, vertical = SyncTokens.Space4),
            verticalAlignment = Alignment.CenterVertically,
            content = content,
        )
        if (showDivider) {
            androidx.compose.material3.HorizontalDivider(
                modifier = Modifier.padding(horizontal = SyncTokens.Space5),
                color = AppSurfaces.cardStroke(),
            )
        }
    }
}

/** Web ds-btn--ghost.ds-btn--sm */
@Composable
fun GhostButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) = PremiumGhostButton(text, onClick, modifier)

@Composable
fun PrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
) = PremiumPrimaryButton(text, onClick, modifier, enabled, loading)

@Composable
fun DangerButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) = PremiumDangerButton(text, onClick, modifier)

@Composable
fun SearchField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String = "Search…",
    modifier: Modifier = Modifier,
) = PremiumSearchField(value, onValueChange, placeholder, modifier)

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
fun LoginHero(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(RoundedCornerShape(SyncTokens.RadiusXl))
                .background(
                    Brush.linearGradient(
                        listOf(SyncTokens.Teal.copy(0.12f), Color.White.copy(0.5f)),
                    ),
                )
                .border(1.dp, Color.White.copy(0.85f), RoundedCornerShape(SyncTokens.RadiusXl)),
            contentAlignment = Alignment.Center,
        ) {
            androidx.compose.foundation.Image(
                painter = androidx.compose.ui.res.painterResource(com.syncbridge.android.R.drawable.ic_app_logo),
                contentDescription = null,
                modifier = Modifier.size(44.dp),
            )
        }
        Spacer(Modifier.height(SyncTokens.Space4))
        Text(
            "SyncBridge",
            fontSize = 24.sp,
            fontWeight = FontWeight.ExtraBold,
            letterSpacing = (-0.3).sp,
            color = SyncTokens.SlateText,
            textAlign = TextAlign.Center,
        )
        Text(
            "Enter your PIN to unlock",
            fontSize = 14.sp,
            color = SyncTokens.SlateSecondary,
            textAlign = TextAlign.Center,
        )
    }
}

/** Web ds-input + ds-error for login PIN field. */
@Composable
fun LoginPinField(
    value: String,
    onValueChange: (String) -> Unit,
    error: String?,
    modifier: Modifier = Modifier,
) = PremiumTextField(
    value = value,
    onValueChange = onValueChange,
    modifier = modifier,
    placeholder = "PIN",
    error = error,
    password = true,
    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
)

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
                .clip(RoundedCornerShape(SyncTokens.RadiusButton))
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
                    .clip(RoundedCornerShape(SyncTokens.RadiusButton))
                    .clickable(onClick = onCopy),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(SyncTokens.RadiusButton))
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
                    .clip(RoundedCornerShape(SyncTokens.RadiusButton))
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
fun ClipboardCard(
    entry: ClipboardEntry,
    onCopy: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
    api: ApiClient? = null,
    deviceName: String? = null,
    transferMode: String? = null,
    copied: Boolean = false,
    inserting: Boolean = false,
    embeddedInGroup: Boolean = false,
    onPin: (() -> Unit)? = null,
    onPreview: (() -> Unit)? = null,
) {
    val isImage = isImageContentType(entry.contentType)
    val large = !isImage && entry.content.length > 180
    val shape = RoundedCornerShape(if (embeddedInGroup) 0.dp else SyncTokens.RadiusContainer)
    val borderColor = when {
        copied -> SyncTokens.Success.copy(alpha = 0.55f)
        entry.pinned -> SyncTokens.Indigo.copy(alpha = 0.35f)
        else -> AppSurfaces.cardStroke()
    }

    Box(modifier.fillMaxWidth()) {
        val shellModifier = if (embeddedInGroup) {
            Modifier.fillMaxWidth()
        } else {
            Modifier
                .fillMaxWidth()
                .floatingCardShadow(shape)
                .clip(shape)
                .background(AppSurfaces.card())
                .border(1.dp, borderColor, shape)
        }

        Box(modifier = shellModifier) {
            Column(
                Modifier.padding(if (embeddedInGroup) SyncTokens.Space5 else SyncTokens.Space4),
                verticalArrangement = Arrangement.spacedBy(SyncTokens.Space2),
            ) {
                if (deviceName != null || entry.pinned || transferMode != null || onPin != null || onPreview != null) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2),
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.weight(1f),
                        ) {
                            deviceName?.let {
                                PremiumChip(label = it, variant = ChipVariant.Neutral)
                            }
                            if (entry.pinned) {
                                PremiumChip(label = "Pinned", variant = ChipVariant.Primary)
                            }
                            transferMode?.let { TransferBadge(transferMode = it) }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space1)) {
                            onPreview?.let { GhostButton(text = "Preview", onClick = it) }
                            onPin?.let {
                                GhostButton(
                                    text = if (entry.pinned) "Unpin" else "Pin",
                                    onClick = it,
                                )
                            }
                        }
                    }
                }

                val contentInteraction = remember { MutableInteractionSource() }
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .pressableScale(contentInteraction)
                        .clickable(
                            interactionSource = contentInteraction,
                            indication = null,
                            onClick = onCopy,
                        ),
                    verticalArrangement = Arrangement.spacedBy(SyncTokens.Space2),
                ) {
                    if (isImage && api != null) {
                        ClipboardImageThumb(
                            entry = entry,
                            api = api,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(180.dp)
                                .clip(RoundedCornerShape(SyncTokens.RadiusLg)),
                            contentDescription = "Clipboard image",
                        )
                    } else {
                        Text(
                            clipboardDisplayText(entry.content, if (large) 480 else 160),
                            fontSize = if (large) 16.sp else 14.sp,
                            lineHeight = if (large) 24.sp else 22.sp,
                            maxLines = if (large) 8 else 4,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.padding(end = SyncTokens.Space6),
                        )
                    }

                    Text(
                        "${relativeTime(entry.createdAt)} · ${if (isImage) "Image" else "Text"} · Tap to copy",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = SyncTokens.SlateMuted,
                    )
                }
            }
        }

        if (copied) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(SyncTokens.Success.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "✓ Copied",
                    color = Color.White,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(SyncTokens.Success)
                        .padding(horizontal = SyncTokens.Space4, vertical = SyncTokens.Space2),
                )
            }
        }

        ItemDeleteButton(
            onClick = onDelete,
            overlay = true,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(SyncTokens.Space2),
        )
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
