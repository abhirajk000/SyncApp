// SharedCards.swift — DeviceCard, TransferCard, AppModal (design/tokens.json)

import SwiftUI

// MARK: - Device Card

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
            HStack(spacing: SyncTokens.space3) {
                Text("🟢")
                VStack(alignment: .leading, spacing: SyncTokens.space1) {
                    Text("\(emoji) \(name)")
                        .font(SyncFont.titleLg())
                        .foregroundStyle(AppSurfaces.onSurface(colorScheme))
                        .lineLimit(1)
                    Text(online ? "Online · \(connectionQuality)" : "Offline")
                        .font(SyncFont.caption())
                        .foregroundStyle(online ? SyncTokens.textMuted : SyncTokens.danger)
                }
                Spacer()
                if selected { ProgressView() }
            }
            .padding(SyncTokens.space4)
            .background(AppSurfaces.card(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusCard))
            .overlay(
                RoundedRectangle(cornerRadius: SyncTokens.radiusCard)
                    .stroke(selected ? SyncTokens.primary.opacity(0.5) : AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

extension DeviceCard {
    init(peer: LocalPeer, selected: Bool, onTap: @escaping () -> Void) {
        self.init(name: peer.name, platform: peer.platform, selected: selected, onTap: onTap)
    }
}

// MARK: - Transfer Card

struct TransferCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let progress: LocalTransferProgress
    var onCancel: (() -> Void)? = nil
    var onOpenFolder: (() -> Void)? = nil
    var onSendMore: (() -> Void)? = nil
    var onDone: (() -> Void)? = nil

    private var total: Int64 { progress.files.reduce(0) { $0 + $1.size } }
    private var done: Int64 { progress.files.reduce(0) { $0 + $1.transferred } }
    private var pct: Double { total > 0 ? Double(done) / Double(total) : 0 }
    private var remaining: Int64 { max(0, total - done) }
    private var eta: Int64 { progress.speedBytesPerSec > 0 ? remaining / progress.speedBytesPerSec : 0 }

    var body: some View {
        AppCard {
            HStack {
                VStack(alignment: .leading, spacing: SyncTokens.space1) {
                    AppCardTitle(title: progress.direction == .sending ? "Sending to \(progress.peerName)" : "Receiving from \(progress.peerName)")
                    Text(phaseText(progress.phase))
                        .font(SyncFont.caption())
                        .foregroundStyle(phaseColor(progress.phase))
                }
                Spacer()
                if progress.phase == .transferring || progress.phase == .paused, let onCancel {
                    PremiumIconButton(systemName: "xmark.circle.fill", tint: SyncTokens.slateMuted, action: onCancel)
                }
            }
            PremiumLinearProgress(progress: pct)
            HStack {
                Text("\(Int(pct * 100))%").font(SyncFont.caption())
                Spacer()
                Text(formatSpeed(progress.speedBytesPerSec)).font(SyncFont.caption()).foregroundStyle(SyncTokens.primary)
            }
            Text("\(formatBytes(done)) / \(formatBytes(total)) · \(formatBytes(remaining)) left\(eta > 0 ? " · ~\(eta)s" : "")")
                .font(SyncFont.caption())
                .foregroundStyle(SyncTokens.textMuted)
            ForEach(progress.files) { file in
                HStack {
                    Text(file.name).font(SyncFont.caption()).lineLimit(1)
                    Spacer()
                    Text("\(Int(file.percent * 100))%").font(SyncFont.caption()).foregroundStyle(SyncTokens.textMuted)
                }
            }
            if progress.phase == .completed {
                Text("Transfer Complete").font(SyncFont.titleLg()).foregroundStyle(SyncTokens.success)
                HStack {
                    if let onOpenFolder { GhostButton(title: "Open Folder", action: onOpenFolder) }
                    if let onSendMore { GhostButton(title: "Send More", action: onSendMore) }
                    if let onDone { PrimaryButton(text: "Done", action: onDone) }
                }
            }
            if let err = progress.error, !err.isEmpty {
                Text(err).font(SyncFont.caption()).foregroundStyle(SyncTokens.danger)
            }
        }
    }

    private func phaseText(_ p: LocalTransferPhase) -> String {
        switch p {
        case .idle: return "Idle"
        case .connecting: return "Connecting"
        case .waitingAccept: return "Waiting"
        case .transferring: return "Transferring"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    private func phaseColor(_ p: LocalTransferPhase) -> Color {
        switch p {
        case .completed: return SyncTokens.success
        case .failed: return SyncTokens.danger
        case .paused: return SyncTokens.warning
        default: return SyncTokens.textMuted
        }
    }

    private func formatSpeed(_ bps: Int64) -> String {
        if bps >= 1_000_000 { return String(format: "%.1f MB/s", Double(bps) / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.1f KB/s", Double(bps) / 1_000) }
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
