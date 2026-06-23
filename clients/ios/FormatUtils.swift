// FormatUtils.swift — Matches Android util/FormatUtils.kt

import Foundation

func relativeTime(_ iso: String) -> String {
    if iso.isEmpty { return "just now" }
    let normalized = iso.contains(" ") && !iso.contains("T")
        ? iso.replacingOccurrences(of: " ", with: "T") + (iso.hasSuffix("Z") ? "" : "Z")
        : iso
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = formatter.date(from: normalized)
        ?? ISO8601DateFormatter().date(from: iso)
        ?? ISO8601DateFormatter().date(from: normalized)
    guard let date else { return "just now" }
    let seconds = Int(-date.timeIntervalSinceNow)
    if seconds < 5 { return "just now" }
    if seconds < 60 { return "\(seconds)s ago" }
    if seconds < 3600 { return "\(seconds / 60)m ago" }
    return "\(seconds / 3600)h ago"
}

func formatBytes(_ n: Int64) -> String {
    if n < 1024 { return "\(n) B" }
    if n < 1024 * 1024 { return String(format: "%.1f KB", Double(n) / 1024.0) }
    return String(format: "%.1f MB", Double(n) / (1024.0 * 1024.0))
}

func clipboardDisplayText(_ content: String, max: Int = 500) -> String {
    let raw = content.trimmingCharacters(in: .whitespacesAndNewlines)
    if raw.isEmpty { return "(empty)" }
    var cleaned = raw
    if raw.contains("<") && raw.contains(">") {
        cleaned = raw.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if cleaned.count <= max { return cleaned }
    return String(cleaned.prefix(max)) + "…"
}

func isImageContentType(_ type: String) -> Bool {
    type.hasPrefix("image/")
}

func isTextMime(_ mime: String) -> Bool {
    mime.hasPrefix("text/") || mime == "application/json"
}

func canCopyFile(_ file: FileItem) -> Bool {
    if file.status != "ready" { return false }
    let ext = (file.name as NSString).pathExtension.lowercased()
    return file.mimeType.hasPrefix("image/")
        || isTextMime(file.mimeType)
        || ["txt", "md", "csv", "json", "log"].contains(ext)
}
