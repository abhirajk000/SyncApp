package com.syncbridge.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.syncbridge.android.network.TransferRoute

@Composable
fun TransferBadge(transferMode: String?, modifier: Modifier = Modifier) {
    val route = TransferRoute.fromTransferMode(transferMode)
    val (bg, fg, border) = when (route) {
        TransferRoute.Cloud -> Triple(Color(0x1F3B82F6), Color(0xFF2563EB), Color(0x333B82F6))
        TransferRoute.DirectLan -> Triple(Color(0x1F22C55E), Color(0xFF15803D), Color(0x4022C55E))
        TransferRoute.WebRtc -> Triple(Color(0x1F8B5CF6), Color(0xFF7C3AED), Color(0x338B5CF6))
    }
    Row(
        modifier = modifier
            .background(bg, RoundedCornerShape(999.dp))
            .border(1.dp, border, RoundedCornerShape(999.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(route.emoji, fontSize = 11.sp)
        Text(
            route.label,
            fontSize = 10.sp,
            fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
            color = fg,
            modifier = Modifier.padding(start = 4.dp),
            style = MaterialTheme.typography.labelSmall,
        )
    }
}
