// LocalSendFlowView.swift — Phase 7 Local Send wizard

import SwiftUI
import UniformTypeIdentifiers

private enum LocalSendStep: Int, CaseIterable {
    case intro, nearby, chooseDevice, chooseFiles, preview, transfer, success

    var label: String {
        switch self {
        case .intro: return "Send"
        case .nearby: return "Nearby"
        case .chooseDevice: return "Device"
        case .chooseFiles: return "Files"
        case .preview: return "Preview"
        case .transfer: return "Transfer"
        case .success: return "Success"
        }
    }
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
                GhostButton(title: step == .intro ? "← Back" : "←") {
                    if step == .intro { onBack() }
                    else if let prev = LocalSendStep(rawValue: step.rawValue - 1) { step = prev }
                }
                Text("Local Send").font(SyncFont.titleLg())
                Spacer()
            }
            .padding(.horizontal, SyncTokens.space4)
            .padding(.top, SyncTokens.space4)

            stepper
                .padding(.horizontal, SyncTokens.space4)
                .padding(.vertical, SyncTokens.space3)

            ScrollView {
                VStack(alignment: .leading, spacing: SyncTokens.space4) {
                    stepContent
                }
                .padding(.horizontal, SyncTokens.space4)
                .padding(.bottom, SyncTokens.space10 + SyncTokens.dockHeight)
            }
            .animation(.easeOut(duration: SyncTokens.durationNormal), value: step)
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
        HStack(spacing: SyncTokens.space1) {
            ForEach(LocalSendStep.allCases, id: \.rawValue) { item in
                Circle()
                    .fill(dotColor(for: item))
                    .frame(width: item == step ? 10 : 8, height: item == step ? 10 : 8)
                if item != .success {
                    Rectangle()
                        .fill(item.rawValue < step.rawValue ? SyncTokens.success.opacity(0.5) : SyncTokens.slateMuted.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
    }

    private func dotColor(for item: LocalSendStep) -> Color {
        if item.rawValue < step.rawValue { return SyncTokens.success }
        if item == step { return SyncTokens.teal }
        return SyncTokens.slateMuted.opacity(0.35)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .intro:
            AppCard {
                HStack(spacing: SyncTokens.space3) {
                    Image(systemName: "wifi")
                        .foregroundStyle(.white)
                        .frame(width: SyncTokens.icon2xl, height: SyncTokens.icon2xl)
                        .background(LinearGradient(colors: [SyncTokens.indigo, SyncTokens.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(Circle())
                    VStack(alignment: .leading) {
                        AppCardTitle(title: "Direct Wi‑Fi transfer")
                        Text("Send files on the same network — no cloud.")
                            .font(SyncFont.bodySm())
                            .foregroundStyle(SyncTokens.slateMuted)
                    }
                }
                PrimaryButton(text: "Start") { step = .nearby }
                    .padding(.top, SyncTokens.space4)
            }
        case .nearby:
            ScanPulseView()
            if localSend.peers.isEmpty {
                AppEmptyState(illustration: .devices, title: "Looking for devices…", description: "Open Local Send on another device on the same Wi‑Fi.")
            } else {
                Text("\(localSend.peers.count) device\(localSend.peers.count == 1 ? "" : "s") nearby")
                    .font(SyncFont.caption())
                    .foregroundStyle(SyncTokens.slateMuted)
                    .frame(maxWidth: .infinity)
                PrimaryButton(text: "Continue") { step = .chooseDevice }
            }
        case .chooseDevice:
            ForEach(localSend.peers) { peer in
                DeviceCard(peer: peer, selected: selectedPeer?.id == peer.id) {
                    selectedPeer = peer
                }
            }
            PrimaryButton(text: "Continue", enabled: selectedPeer != nil) { step = .chooseFiles }
        case .chooseFiles:
            AppCard {
                Text("Select files to send over Wi‑Fi.").font(SyncFont.bodySm()).foregroundStyle(SyncTokens.slateMuted)
                PrimaryButton(text: "Choose files") { showFilePicker = true }
                    .padding(.top, SyncTokens.space3)
            }
        case .preview:
            Text("Sending to \(selectedPeer?.name ?? "device")")
                .font(SyncFont.bodySm().weight(.semibold))
            ForEach(pendingFiles) { file in
                HStack {
                    Text(file.name).lineLimit(1)
                    Spacer()
                    Text(formatBytes(file.size)).font(SyncFont.caption()).foregroundStyle(SyncTokens.slateMuted)
                }
                .padding(SyncTokens.space4)
                .background(AppSurfaces.card(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusLg))
            }
            PrimaryButton(text: "Send now") {
                if let peer = selectedPeer {
                    localSend.send(to: peer, urls: pendingFiles.map(\.url))
                    step = .transfer
                }
            }
        case .transfer:
            if let p = localSend.progress {
                TransferCard(
                    progress: p,
                    onCancel: localSend.cancelTransfer,
                    onOpenFolder: localSend.openReceiveFolder,
                    onSendMore: { showFilePicker = true },
                    onDone: localSend.cancelTransfer
                )
            } else {
                Text("Starting transfer…").foregroundStyle(SyncTokens.slateMuted)
            }
        case .success:
            VStack(spacing: SyncTokens.space4) {
                Text("✓")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(SyncTokens.success)
                    .clipShape(Circle())
                Text("Transfer complete").font(SyncFont.titleLg())
                Text("Delivered to \(selectedPeer?.name ?? localSend.progress?.peerName ?? "device") over Wi‑Fi.")
                    .font(SyncFont.bodySm())
                    .foregroundStyle(SyncTokens.slateMuted)
                    .multilineTextAlignment(.center)
                HStack(spacing: SyncTokens.space2) {
                    GhostButton(title: "Send more") {
                        localSend.cancelTransfer()
                        pendingFiles = []
                        selectedPeer = nil
                        step = .intro
                    }
                    PrimaryButton(text: "Done", action: onBack)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, SyncTokens.space6)
        }
    }
}

private struct ScanPulseView: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Circle()
                .stroke(SyncTokens.teal.opacity(0.35), lineWidth: 2)
                .frame(width: pulse ? 110 : 90, height: pulse ? 110 : 90)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
            Image(systemName: "wifi")
                .font(.title)
                .foregroundStyle(SyncTokens.teal)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .onAppear { pulse = true }
    }
}
