package com.syncbridge.android.util

import java.time.Instant
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

fun relativeTime(iso: String): String {
    if (iso.isBlank()) return "just now"
    return try {
        val instant = Instant.parse(iso.replace(" ", "T").let {
            if (it.endsWith("Z") || it.contains("+")) it else "${it}Z"
        })
        val seconds = ChronoUnit.SECONDS.between(instant, Instant.now())
        when {
            seconds < 5 -> "just now"
            seconds < 60 -> "${seconds}s ago"
            seconds < 3600 -> "${seconds / 60}m ago"
            else -> "${seconds / 3600}h ago"
        }
    } catch (_: Exception) {
        try {
            val f = DateTimeFormatter.ISO_DATE_TIME
            val instant = java.time.ZonedDateTime.parse(iso, f).toInstant()
            val seconds = ChronoUnit.SECONDS.between(instant, Instant.now())
            if (seconds < 60) "${seconds}s ago" else "${seconds / 60}m ago"
        } catch (_: Exception) {
            "just now"
        }
    }
}

fun formatBytes(n: Long): String = when {
    n < 1024 -> "$n B"
    n < 1024 * 1024 -> "${"%.1f".format(n / 1024.0)} KB"
    else -> "${"%.1f".format(n / (1024.0 * 1024.0))} MB"
}

fun truncate(text: String, max: Int): String {
    val t = text.trim()
    return if (t.length > max) t.take(max) + "…" else t.ifEmpty { "(empty)" }
}

fun stripHtml(html: String): String =
    html.replace(Regex("<[^>]+>"), " ")
        .replace(Regex("&nbsp;"), " ")
        .replace(Regex("&amp;"), "&")
        .replace(Regex("&lt;"), "<")
        .replace(Regex("&gt;"), ">")
        .replace(Regex("\\s+"), " ")
        .trim()

fun clipboardDisplayText(content: String, max: Int = 500): String {
    val raw = content.trim()
    if (raw.isEmpty()) return "(empty)"
    val cleaned = if (raw.contains('<') && raw.contains('>')) stripHtml(raw) else raw
    return truncate(cleaned, max)
}
