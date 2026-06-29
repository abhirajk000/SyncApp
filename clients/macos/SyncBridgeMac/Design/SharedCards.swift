// SharedCards.swift — DeviceCard, TransferCard (macOS)

import SwiftUI

struct DeviceCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let name: String
    let platform: String
    var online: Bool = true
    var connectionQuality: String = "Excellent"
    var selected: Bool = false
    let onTap: () -> Void

    private var emoji: String {
        switch platform.lowercased() {
        case "macos": return "💻"
        case "android", "ios": return "📱"
        case "windows": return "🖥️"
        default: return "📟"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Space.lg) {
                Text("🟢")
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(emoji) \(name)").font(SyncFont.titleLg()).foregroundStyle(DS.Color.textAdaptive(colorScheme))
                    Text(online ? "Online · \(connectionQuality)" : "Offline")
                        .font(SyncFont.caption()).foregroundStyle(online ? DS.Color.muted : DS.Color.danger)
                }
                Spacer()
                if selected { ProgressView().controlSize(.small) }
            }
            .padding(DS.Space.lg)
            .glassCard(cornerRadius: DS.Radius.card)
        }
        .buttonStyle(.plain)
    }
}

extension DeviceCard {
    init(peer: LocalPeer, selected: Bool, onTap: @escaping () -> Void) {
        self.init(name: peer.name, platform: peer.platform, selected: selected, onTap: onTap)
    }
}

struct TransferCard: View {
    let progress: LocalTransferProgress
    var onCancel: (() -> Void)? = nil
    var onOpenFolder: (() -> Void)? = nil
    var onSendMore: (() -> Void)? = nil
    var onDone: (() -> Void)? = nil

    private var total: Int64 { progress.files.reduce(0) { $0 + $1.size } }
    private var done: Int64 { progress.files.reduce(0) { $0 + $1.transferred } }
    private var pct: Double { total > 0 ? Double(done) / Double(total) : 0 }

    var body: some View {
        AppCard {
            HStack {
                VStack(alignment: .leading) {
                    Text(progress.direction == .sending ? "Sending to \(progress.peerName)" : "Receiving from \(progress.peerName)")
                        .font(SyncFont.titleLg())
                    Text(progress.phase == .transferring ? "Transferring" : "\(progress.phase)")
                        .font(SyncFont.caption()).foregroundStyle(DS.Color.muted)
                }
                Spacer()
                if let onCancel, progress.phase == .transferring || progress.phase == .paused {
                    PremiumIconButton(systemName: "xmark.circle.fill", action: onCancel)
                }
            }
            PremiumLinearProgress(progress: pct)
            HStack {
                Text("\(Int(pct * 100))%").font(SyncFont.caption())
                Spacer()
                Text(formatSpeed(progress.speedBytesPerSec)).font(SyncFont.caption()).foregroundStyle(DS.Color.primary)
            }
            if progress.phase == .completed {
                Text("Transfer Complete").font(SyncFont.titleLg()).foregroundStyle(DS.Color.success)
                HStack {
                    if let onOpenFolder { AppButton(title: "Open Folder", variant: .ghost, action: onOpenFolder) }
                    if let onSendMore { AppButton(title: "Send More", variant: .ghost, action: onSendMore) }
                    if let onDone { AppButton(title: "Done", variant: .primary, action: onDone) }
                }
            }
        }
    }

    private func formatSpeed(_ bps: Int64) -> String {
        if bps >= 1_000_000 { return String(format: "%.1f MB/s", Double(bps) / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0f KB/s", Double(bps) / 1_000) }
        return bps > 0 ? "\(bps) B/s" : "—"
    }
}

// MARK: - App Modal

struct AppModal: View {
    let title: String
    let message: String
    let confirmText: String
    let dismissText: String
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        PremiumAppModalOverlay(
            title: title,
            message: message,
            confirmText: confirmText,
            dismissText: dismissText,
            onConfirm: onConfirm,
            onDismiss: onDismiss
        )
    }
}

// MARK: - Clipboard Card

struct ClipboardCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: ClipboardEntryResponse
    let onCopy: () -> Void
    let onDelete: () -> Void
    var deviceName: String? = nil
    var transferMode: String? = nil
    var copied: Bool = false
    var onPin: (() -> Void)? = nil
    var onPreview: (() -> Void)? = nil

    private var isImage: Bool { entry.contentType.hasPrefix("image/") }
    private var large: Bool { !isImage && entry.content.count > 180 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                if deviceName != nil || entry.pinned || transferMode != nil || onPin != nil || onPreview != nil {
                    HStack {
                        HStack(spacing: DS.Space.xs) {
                            if let deviceName {
                                PremiumChip(label: deviceName, variant: .neutral)
                            }
                            if entry.pinned {
                                PremiumChip(label: "Pinned", variant: .primary)
                            }
                            if let transferMode {
                                TransferBadgeView(transferMode: transferMode)
                            }
                        }
                        Spacer()
                        HStack(spacing: DS.Space.xs) {
                            if let onPreview {
                                AppButton(title: "Preview", variant: .ghost, action: onPreview)
                            }
                            if let onPin {
                                AppButton(title: entry.pinned ? "Unpin" : "Pin", variant: .ghost, action: onPin)
                            }
                        }
                    }
                }

                Button(action: onCopy) {
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        if isImage {
                            ClipboardImageThumb(entry: entry, maxHeight: 180)
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                        } else {
                            Text(ClipboardDisplay.previewText(for: entry, maxLength: large ? 480 : 160))
                                .font(large ? DS.Font.body() : DS.Font.bodySm())
                                .foregroundStyle(DS.Color.textAdaptive(colorScheme))
                                .lineLimit(large ? 8 : 3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, DS.Space.xl)
                        }
                        Text("\(relativeTimeShort(entry.createdAt)) · \(isImage ? "Image" : "Text") · Tap to copy")
                            .font(DS.Font.caption())
                            .foregroundStyle(.secondary)
                    }
                    .padding(DS.Space.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .adaptiveGlassCard(cornerRadius: DS.Radius.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.card)
                            .stroke(
                                copied ? DS.Color.success : (entry.pinned ? DS.Color.secondary.opacity(0.35) : Color.clear),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }

            if copied {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.card)
                        .fill(DS.Color.success.opacity(0.12))
                    Text("✓ Copied")
                        .font(DS.Font.bodySm().weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Space.md)
                        .padding(.vertical, DS.Space.xs)
                        .background(DS.Color.success)
                        .clipShape(Capsule())
                }
                .allowsHitTesting(false)
            }

            ItemDeleteButton(overlay: true, action: onDelete)
                .padding(DS.Space.sm)
        }
    }
}

private func clipboardDate(_ isoString: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: isoString) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: isoString) ?? .distantPast
}

private func relativeTimeShort(_ isoString: String) -> String {
    let date = clipboardDate(isoString)
    guard date != .distantPast else { return isoString }
    let rel = RelativeDateTimeFormatter()
    rel.unitsStyle = .short
    return rel.localizedString(for: date, relativeTo: Date())
}
