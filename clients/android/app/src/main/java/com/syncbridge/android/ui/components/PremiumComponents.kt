package com.syncbridge.android.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.syncbridge.android.ui.theme.SyncTokens

// ── Buttons (no Material Button) ─────────────────────────────────────────────

@Composable
fun PremiumPrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
    block: Boolean = true,
) {
    val shape = RoundedCornerShape(SyncTokens.RadiusButton)
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    Box(
        modifier = modifier
            .then(if (block) Modifier.fillMaxWidth() else Modifier)
            .scale(if (pressed) 0.97f else 1f)
            .height(56.dp)
            .clip(shape)
            .background(
                if (enabled && !loading) {
                    Brush.linearGradient(listOf(SyncTokens.Teal, SyncTokens.TealLight))
                } else {
                    Brush.linearGradient(listOf(SyncTokens.Teal.copy(0.4f), SyncTokens.TealLight.copy(0.4f)))
                },
            )
            .clickable(
                enabled = enabled && !loading,
                interactionSource = interaction,
                indication = null,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        if (loading) {
            Row(horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2), verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp, color = Color.White)
                Text(text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
            }
        } else {
            Text(text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
        }
    }
}

@Composable
fun PremiumGhostButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(SyncTokens.RadiusSm)
    Box(
        modifier = modifier
            .heightIn(min = 32.dp)
            .clip(shape)
            .border(1.dp, AppSurfaces.cardStroke(), shape)
            .background(Color.Transparent)
            .clickable(onClick = onClick)
            .padding(horizontal = SyncTokens.Space4, vertical = SyncTokens.Space2),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = SyncTokens.SlateSecondary)
    }
}

@Composable
fun PremiumDangerButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(SyncTokens.RadiusButton)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(48.dp)
            .clip(shape)
            .background(SyncTokens.Danger.copy(0.12f))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = SyncTokens.Danger)
    }
}

@Composable
fun PremiumIconButton(
    onClick: () -> Unit,
    icon: ImageVector,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    tint: Color = SyncTokens.SlateSecondary,
) {
    Box(
        modifier = modifier
            .size(40.dp)
            .clip(CircleShape)
            .border(1.dp, AppSurfaces.cardStroke(), CircleShape)
            .background(AppSurfaces.card())
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription, tint = tint, modifier = Modifier.size(20.dp))
    }
}

// ── Inputs ────────────────────────────────────────────────────────────────────

@Composable
fun PremiumTextField(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String = "",
    error: String? = null,
    singleLine: Boolean = true,
    minLines: Int = 1,
    password: Boolean = false,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
) {
    val shape = RoundedCornerShape(SyncTokens.RadiusInput)
    val borderColor = if (error != null) SyncTokens.Danger else AppSurfaces.cardStroke()
    Column(modifier = modifier.fillMaxWidth()) {
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier
                .fillMaxWidth()
                .clip(shape)
                .border(1.dp, borderColor, shape)
                .background(AppSurfaces.card())
                .padding(horizontal = SyncTokens.Space4, vertical = SyncTokens.Space3),
            textStyle = TextStyle(fontSize = 14.sp, color = SyncTokens.SlateText),
            singleLine = singleLine,
            minLines = minLines,
            visualTransformation = if (password) PasswordVisualTransformation() else VisualTransformation.None,
            keyboardOptions = keyboardOptions,
            cursorBrush = SolidColor(SyncTokens.Teal),
            decorationBox = { inner ->
                Box {
                    if (value.isEmpty() && placeholder.isNotEmpty()) {
                        Text(placeholder, color = SyncTokens.SlateMuted, fontSize = 14.sp)
                    }
                    inner()
                }
            },
        )
        error?.let {
            Text(it, color = SyncTokens.Danger, fontSize = 13.sp, modifier = Modifier.padding(top = SyncTokens.Space2))
        }
    }
}

@Composable
fun PremiumSearchField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String = "Search…",
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(SyncTokens.RadiusContainerSm)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(48.dp)
            .clip(shape)
            .border(1.dp, AppSurfaces.cardStroke(), shape)
            .background(AppSurfaces.card())
            .padding(horizontal = SyncTokens.Space4),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space2),
    ) {
        Icon(Icons.Outlined.Search, null, tint = SyncTokens.SlateMuted, modifier = Modifier.size(18.dp))
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.fillMaxWidth(),
            textStyle = TextStyle(fontSize = 14.sp, color = SyncTokens.SlateText),
            singleLine = true,
            cursorBrush = SolidColor(SyncTokens.Teal),
            decorationBox = { inner ->
                Box(Modifier.fillMaxWidth()) {
                    if (value.isEmpty()) Text(placeholder, color = SyncTokens.SlateMuted, fontSize = 14.sp)
                    inner()
                }
            },
        )
    }
}

// ── Dialog (no AlertDialog) ─────────────────────────────────────────────────

@Composable
fun PremiumAppModal(
    title: String,
    message: String,
    confirmText: String,
    dismissText: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(
            Modifier
                .fillMaxWidth(0.9f)
                .clip(RoundedCornerShape(SyncTokens.RadiusContainerLg))
                .background(AppSurfaces.card())
                .border(1.dp, AppSurfaces.cardStroke(), RoundedCornerShape(SyncTokens.RadiusContainerLg))
                .padding(SyncTokens.Space6),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(SyncTokens.Space4)) {
                Text(title, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = SyncTokens.SlateText)
                Text(message, fontSize = 14.sp, color = SyncTokens.SlateSecondary, lineHeight = 22.sp)
                Row(horizontalArrangement = Arrangement.spacedBy(SyncTokens.Space3)) {
                    PremiumGhostButton(dismissText, onDismiss, modifier = Modifier.weight(1f))
                    PremiumPrimaryButton(confirmText, onConfirm, modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

// ── Bottom sheet ────────────────────────────────────────────────────────────

@Composable
fun PremiumBottomSheet(
    visible: Boolean,
    title: String?,
    onDismiss: () -> Unit,
    content: @Composable () -> Unit,
) {
    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(tween(SyncTokens.DurationNormal)) + slideInVertically { it },
        exit = fadeOut(tween(SyncTokens.DurationFast)) + slideOutVertically { it },
    ) {
        Box(Modifier.fillMaxSize()) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(0.55f))
                    .clickable(indication = null, interactionSource = remember { MutableInteractionSource() }) { onDismiss() },
            )
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(topStart = SyncTokens.RadiusContainerLg, topEnd = SyncTokens.RadiusContainerLg))
                    .background(AppSurfaces.card())
                    .border(1.dp, AppSurfaces.cardStroke(), RoundedCornerShape(topStart = SyncTokens.RadiusContainerLg, topEnd = SyncTokens.RadiusContainerLg))
                    .padding(SyncTokens.Space6),
            ) {
                Box(
                    Modifier
                        .width(36.dp)
                        .height(4.dp)
                        .clip(CircleShape)
                        .background(SyncTokens.CardBorder)
                        .align(Alignment.CenterHorizontally),
                )
                Spacer(Modifier.height(SyncTokens.Space4))
                title?.let {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text(it, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
                        PremiumIconButton(onClick = onDismiss, icon = Icons.Outlined.Close, contentDescription = "Close")
                    }
                    Spacer(Modifier.height(SyncTokens.Space3))
                }
                content()
            }
        }
    }
}

// ── Skeleton ────────────────────────────────────────────────────────────────

@Composable
fun PremiumSkeleton(rows: Int = 4, modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "shimmer")
    val offset by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(1400, easing = LinearEasing), RepeatMode.Restart),
        label = "shimmer",
    )
    Column(modifier, verticalArrangement = Arrangement.spacedBy(SyncTokens.Space3)) {
        Box(
            Modifier
                .fillMaxWidth(0.4f)
                .height(24.dp)
                .clip(RoundedCornerShape(SyncTokens.RadiusMd))
                .background(shimmerBrush(offset)),
        )
        repeat(rows) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(56.dp)
                    .clip(RoundedCornerShape(SyncTokens.RadiusCard))
                    .background(shimmerBrush(offset)),
            )
        }
    }
}

private fun shimmerBrush(progress: Float): Brush {
    val base = SyncTokens.SlateMuted.copy(0.15f)
    val highlight = SyncTokens.SlateMuted.copy(0.28f)
    return Brush.horizontalGradient(
        colors = listOf(base, highlight, base),
        startX = progress * 800f,
        endX = progress * 800f + 400f,
    )
}

// ── Progress ────────────────────────────────────────────────────────────────

@Composable
fun PremiumLinearProgress(
    progress: Float,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape(999.dp)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(6.dp)
            .clip(shape)
            .background(SyncTokens.CardBorder),
    ) {
        Box(
            Modifier
                .fillMaxHeight()
                .fillMaxWidth(progress.coerceIn(0f, 1f))
                .clip(shape)
                .background(Brush.horizontalGradient(listOf(SyncTokens.Teal, SyncTokens.TealLight))),
        )
    }
}

// ── Chips ───────────────────────────────────────────────────────────────────

enum class ChipVariant { Success, Warning, Danger, Primary, Neutral }

@Composable
fun PremiumChip(
    label: String,
    variant: ChipVariant = ChipVariant.Neutral,
    modifier: Modifier = Modifier,
) {
    val (bg, fg) = when (variant) {
        ChipVariant.Success -> SyncTokens.Success.copy(0.12f) to SyncTokens.Success
        ChipVariant.Warning -> SyncTokens.Warning.copy(0.12f) to SyncTokens.Warning
        ChipVariant.Danger -> SyncTokens.Danger.copy(0.12f) to SyncTokens.Danger
        ChipVariant.Primary -> SyncTokens.Teal.copy(0.12f) to SyncTokens.Teal
        ChipVariant.Neutral -> SyncTokens.SlateMuted.copy(0.12f) to SyncTokens.SlateSecondary
    }
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(SyncTokens.RadiusChip))
            .background(bg)
            .padding(horizontal = 12.dp, vertical = 6.dp),
    ) {
        Text(label, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = fg)
    }
}
