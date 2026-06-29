package com.syncbridge.android.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.syncbridge.android.network.NetworkSnapshot
import com.syncbridge.android.ui.MainTab
import com.syncbridge.android.ui.theme.SyncTokens

private val pageTransitionMs = SyncTokens.DurationNormal

/** Unified app shell — glass top bar, animated content, floating dock (Phase 2). */
@Composable
fun AppShell(
    currentTab: MainTab,
    connected: Boolean,
    refreshing: Boolean,
    onRefresh: () -> Unit,
    network: NetworkSnapshot?,
    onNavigate: (MainTab) -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable (MainTab) -> Unit,
) {
    Box(modifier.fillMaxSize()) {
        AppBackground()
        androidx.compose.material3.Scaffold(
            containerColor = Color.Transparent,
            topBar = {
                AppTopBar(
                    connected = connected,
                    refreshing = refreshing,
                    onRefresh = onRefresh,
                    network = network,
                )
            },
            bottomBar = {
                DockBottomBar(current = currentTab, onNavigate = onNavigate)
            },
        ) { padding ->
            AnimatedContent(
                targetState = currentTab,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding),
                transitionSpec = {
                    (fadeIn(tween(pageTransitionMs)) + slideInHorizontally { it / 8 })
                        .togetherWith(fadeOut(tween(pageTransitionMs / 2)) + slideOutHorizontally { -it / 8 })
                },
                label = "shell-page",
            ) { tab ->
                content(tab)
            }
        }
    }
}
