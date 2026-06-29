// LocalSendFlowView.swift — Phase 7 Local Send wizard (macOS)

import SwiftUI
import UniformTypeIdentifiers

private enum LocalSendStep: Int, CaseIterable {
    case intro, nearby, chooseDevice, chooseFiles, preview, transfer, success
}

private struct PendingFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
}

struct LocalSendFlowView: View {
    @EnvironmentObject var localSend: LocalSendManager
    @Environment(\.colorScheme) private var colorScheme

    let onBack: () -> Void

    @State private var step: LocalSendStep = .intro
    @State private var selectedPeer: LocalPeer?
    @State private var pendingFiles: [PendingFile] = []
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                AppButton(title: step == .intro ? "← Back" : "←", variant: .ghost, action: {
                    if step == .intro { onBack() }
                    else if let prev = LocalSendStep(rawValue: step.rawValue - 1) { step = prev }
                })
                Text("Local Send").font(SyncFont.titleLg())
                Spacer()
            }
            .padding(DS.Space.md)

            stepper.padding(.horizontal, DS.Space.md).padding(.bottom, DS.Space.sm)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.md) {
                    stepContent
                }
                .padding(DS.Space.md)
            }
            .animation(.easeOut(duration: DS.Duration.normal), value: step)
        }
        .onChange(of: localSend.progress?.phase) { phase in
            guard let phase else { return }
            switch phase {
            case .connecting, .waitingAccept, .transferring:
                if step.rawValue < LocalSendStep.transfer.rawValue { step = .transfer }
            case .completed:
                step = .success
            default:
                break
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            guard case let .success(urls) = result else { return }
            pendingFiles = urls.compactMap { url in
                guard url.startAccessingSecurityScopedResource() else { return nil }
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .localizedNameKey])
                return PendingFile(url: url, name: values?.localizedName ?? url.lastPathComponent, size: Int64(values?.fileSize ?? 0))
            }
            if !pendingFiles.isEmpty { step = .preview }
        }
        .alert(
            "Incoming transfer",
            isPresented: Binding(get: { localSend.incomingOffer != nil }, set: { if !$0 { localSend.rejectIncoming() } }),
            presenting: localSend.incomingOffer
        ) { _ in
            Button("Accept") { localSend.acceptIncoming() }
            Button("Decline", role: .cancel) { localSend.rejectIncoming() }
        } message: { offer in
            Text("\(offer.offer.sender) wants to send:\n\(offer.offer.files.map(\.name).joined(separator: ", "))")
        }
    }

    private var stepper: some View {
        HStack(spacing: 4) {
            ForEach(LocalSendStep.allCases, id: \.rawValue) { item in
                Circle()
                    .fill(item.rawValue < step.rawValue ? DS.Color.success : (item == step ? DS.Color.primary : DS.Color.muted.opacity(0.35)))
                    .frame(width: item == step ? 10 : 8, height: item == step ? 10 : 8)
                if item != .success {
                    Rectangle()
                        .fill(item.rawValue < step.rawValue ? DS.Color.success.opacity(0.5) : DS.Color.muted.opacity(0.25))
                        .frame(height: 2)
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .intro:
            AppCard {
                HStack(spacing: DS.Space.md) {
                    Image(systemName: "wifi")
                        .foregroundStyle(.white)
                        .frame(width: DS.Icon.xxl, height: DS.Icon.xxl)
                        .background(LinearGradient(colors: [DS.Color.secondary, DS.Color.muted], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(Circle())
                    VStack(alignment: .leading) {
                        Text("Direct Wi‑Fi transfer").font(SyncFont.titleLg())
                        Text("No cloud upload.").font(SyncFont.caption()).foregroundStyle(DS.Color.muted)
                    }
                }
                AppButton(title: "Start", variant: .primary) { step = .nearby }
                    .padding(.top, DS.Space.md)
            }
        case .nearby:
            ScanPulseView()
            if localSend.peers.isEmpty {
                AppEmptyState(illustration: .devices, title: "Looking for devices…", description: "Open Local Send on another device on the same Wi‑Fi.")
            } else {
                Text("\(localSend.peers.count) nearby").font(SyncFont.caption()).foregroundStyle(DS.Color.muted)
                AppButton(title: "Continue", variant: .primary) { step = .chooseDevice }
            }
        case .chooseDevice:
            ForEach(localSend.peers) { peer in
                DeviceCard(peer: peer, selected: selectedPeer?.id == peer.id) { selectedPeer = peer }
            }
            AppButton(title: "Continue", variant: .primary) { step = .chooseFiles }
                .disabled(selectedPeer == nil)
        case .chooseFiles:
            AppCard {
                Text("Select files to send.").font(SyncFont.caption())
                AppButton(title: "Choose files", variant: .primary) { showFilePicker = true }
                    .padding(.top, DS.Space.sm)
            }
        case .preview:
            Text("To \(selectedPeer?.name ?? "device")").font(SyncFont.caption())
            ForEach(pendingFiles) { file in
                HStack {
                    Text(file.name).lineLimit(1)
                    Spacer()
                    Text(formatBytes(file.size)).font(SyncFont.caption()).foregroundStyle(DS.Color.muted)
                }
                .padding(DS.Space.md)
                .adaptiveGlassCard(cornerRadius: DS.Radius.lg)
            }
            AppButton(title: "Send now", variant: .primary) {
                if let peer = selectedPeer {
                    localSend.send(to: peer, urls: pendingFiles.map(\.url))
                    step = .transfer
                }
            }
        case .transfer:
            if let p = localSend.progress {
                TransferCard(progress: p, onCancel: localSend.cancelTransfer, onOpenFolder: localSend.openReceiveFolder, onSendMore: { showFilePicker = true }, onDone: localSend.cancelTransfer)
            }
        case .success:
            VStack(spacing: DS.Space.md) {
                Text("✓").font(.largeTitle).foregroundStyle(.white)
                    .frame(width: 72, height: 72).background(DS.Color.success).clipShape(Circle())
                Text("Transfer complete").font(SyncFont.titleLg())
                HStack {
                    AppButton(title: "Send more", variant: .ghost) {
                        localSend.cancelTransfer()
                        pendingFiles = []
                        selectedPeer = nil
                        step = .intro
                    }
                    AppButton(title: "Done", variant: .primary, action: onBack)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ScanPulseView: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Circle().stroke(DS.Color.primary.opacity(0.35), lineWidth: 2)
                .frame(width: pulse ? 110 : 90, height: pulse ? 110 : 90)
            Image(systemName: "wifi").foregroundStyle(DS.Color.primary)
        }
        .frame(maxWidth: .infinity).frame(height: 120)
        .onAppear { withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

private func formatBytes(_ bytes: Int64) -> String {
    if bytes >= 1_000_000 { return String(format: "%.1f MB", Double(bytes) / 1_000_000) }
    if bytes >= 1_000 { return String(format: "%.0f KB", Double(bytes) / 1_000) }
    return "\(bytes) B"
}
