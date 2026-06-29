// LocalSendView.swift — AirDrop-style LAN file transfer UI

import SwiftUI
import UniformTypeIdentifiers

struct LocalSendView: View {
    @EnvironmentObject var localSend: LocalSendManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedPeer: LocalPeer?
    @State private var showFilePicker = false
    @State private var pendingURLs: [URL] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                AppCard {
                    HStack(spacing: DS.Space.md) {
                        Image(systemName: "wifi")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: DS.Icon.xxl, height: DS.Icon.xxl)
                            .background(LinearGradient(colors: [DS.Color.primary, DS.Color.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(Circle())
                        VStack(alignment: .leading) {
                            Text("Local Send").font(SyncFont.titleLg())
                            Text("Direct LAN transfer — no cloud.").font(SyncFont.caption()).foregroundStyle(DS.Color.muted)
                        }
                    }
                }

                if let p = localSend.progress {
                    TransferCard(
                        progress: p,
                        onCancel: localSend.cancelTransfer,
                        onOpenFolder: localSend.openReceiveFolder,
                        onSendMore: { showFilePicker = true },
                        onDone: localSend.cancelTransfer
                    )
                }

                HStack {
                    Text("Nearby devices").font(SyncFont.titleLg())
                    Spacer()
                    Text("\(localSend.peers.count) found").font(SyncFont.caption()).foregroundStyle(DS.Color.muted)
                }

                if localSend.peers.isEmpty {
                    AppEmptyState(illustration: .devices, title: "Looking for devices…", description: "Open Local Send on another device on the same Wi‑Fi.")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Space.xl)
                } else {
                    ForEach(localSend.peers) { peer in
                        DeviceCard(peer: peer, selected: selectedPeer?.id == peer.id) {
                            selectedPeer = selectedPeer?.id == peer.id ? nil : peer
                            if !pendingURLs.isEmpty, let p = selectedPeer {
                                localSend.send(to: p, urls: pendingURLs)
                                pendingURLs = []
                                selectedPeer = nil
                            }
                        }
                    }
                }

                AppButton(title: selectedPeer != nil ? "Send files to \(selectedPeer!.name)" : "Choose files to send", variant: .secondary) {
                    showFilePicker = true
                }

                Text("Receiver saves files to Downloads/SyncBridge.")
                    .font(SyncFont.caption())
                    .foregroundStyle(DS.Color.muted)
            }
            .padding(DS.Space.md)
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            guard case let .success(urls) = result else { return }
            let scoped = urls.filter { $0.startAccessingSecurityScopedResource() }
            if let peer = selectedPeer {
                localSend.send(to: peer, urls: scoped)
                selectedPeer = nil
            } else {
                pendingURLs = scoped
            }
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
}
