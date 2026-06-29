package com.syncbridge.android.ui.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

@Composable
fun AppSkeleton(rows: Int = 4, modifier: Modifier = Modifier) =
    PremiumSkeleton(rows = rows, modifier = modifier)
