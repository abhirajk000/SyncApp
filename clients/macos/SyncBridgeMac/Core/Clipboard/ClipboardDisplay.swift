// ClipboardDisplay.swift — Plain-text preview for clipboard entries (strip HTML/RTF noise).

import AppKit
import Foundation

enum ClipboardDisplay {

    /// User-visible preview text for list rows and cards.
    static func previewText(for entry: ClipboardEntryResponse, maxLength: Int = 280) -> String {
        let raw = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let plain: String
        if entry.contentType == "text/html" || looksLikeHTML(raw) {
            plain = stripHTML(raw)
        } else if entry.contentType == "text/rtf" {
            plain = stripRTF(raw) ?? raw
        } else {
            plain = raw
        }
        let cleaned = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count <= maxLength { return cleaned.isEmpty ? "Empty" : cleaned }
        return String(cleaned.prefix(maxLength)) + "…"
    }

    private static func looksLikeHTML(_ text: String) -> Bool {
        text.contains("<") && (text.contains("</") || text.contains("/>") || text.contains("<span"))
    }

    static func stripHTML(_ html: String) -> String {
        if let data = html.data(using: .utf8) {
            let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ]
            if let attr = try? NSAttributedString(data: data, options: opts, documentAttributes: nil) {
                let s = attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { return s }
            }
        }
        var s = html
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "")
        }
        return s
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripRTF(_ rtf: String) -> String? {
        guard let data = rtf.data(using: .utf8) else { return nil }
        let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf,
        ]
        return try? NSAttributedString(data: data, options: opts, documentAttributes: nil).string
    }
}
