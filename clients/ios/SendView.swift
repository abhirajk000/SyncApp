// SendView.swift — Matches Android SendScreen.kt

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct SendView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    @State private var text = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showFilePicker = false
    @State private var showCamera = false
    @State private var toast: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: SyncTokens.space6) {
                    Text("Send text, images, or files to your connected devices.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(AppSurfaces.onSurfaceVariant(colorScheme))

                    AppCard {
                        AppCardTitle(title: "Quick send text")
                        TextEditor(text: $text)
                            .frame(minHeight: 120)
                            .padding(SyncTokens.space2)
                            .background(AppSurfaces.surfaceVariant(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusMd))
                            .overlay(
                                RoundedRectangle(cornerRadius: SyncTokens.radiusMd)
                                    .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
                            )
                            .overlay(alignment: .topLeading) {
                                if text.isEmpty {
                                    Text("Paste or type anything…")
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundStyle(SyncTokens.slateMuted)
                                        .padding(SyncTokens.space4)
                                        .allowsHitTesting(false)
                                }
                            }
                        PrimaryButton(
                            text: "Send",
                            enabled: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            Task {
                                await appState.sendText(text)
                                text = ""
                                showToast("Sent")
                            }
                        }
                        .padding(.top, SyncTokens.space3)
                    }

                    AppCard {
                        AppCardTitle(title: "Send image")
                        AppCardDesc(text: "Pick from gallery or take a photo.")
                        VStack(spacing: SyncTokens.space3) {
                            Image(systemName: "photo")
                                .font(.system(size: 28))
                                .foregroundStyle(SyncTokens.slateMuted)
                            HStack(spacing: SyncTokens.space2) {
                                PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .images) {
                                    Text("Gallery")
                                        .frame(minWidth: 80)
                                }
                                .buttonStyle(.bordered)
                                .onChange(of: photoItems) { items in
                                    Task {
                                        for item in items {
                                            if let data = try? await item.loadTransferable(type: Data.self) {
                                                let name = "image-\(Int(Date().timeIntervalSince1970)).jpg"
                                                await appState.uploadImageData(data, name: name)
                                            }
                                        }
                                        photoItems = []
                                    }
                                }
                                Button("Camera") { showCamera = true }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: SyncTokens.radiusLg)
                                .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
                        )
                    }

                    AppCard {
                        AppCardTitle(title: "Send files")
                        AppCardDesc(text: "Upload documents and other files to your devices.")
                        VStack(spacing: SyncTokens.space3) {
                            Image(systemName: "arrow.up.doc")
                                .font(.system(size: 28))
                                .foregroundStyle(SyncTokens.slateMuted)
                            Text("Choose files from your device")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(AppSurfaces.onSurfaceVariant(colorScheme))
                            Button("Browse files") { showFilePicker = true }
                                .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SyncTokens.space6)
                        .padding(.horizontal, SyncTokens.space8)
                        .overlay(
                            RoundedRectangle(cornerRadius: SyncTokens.radiusLg)
                                .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
                        )

                        ForEach(appState.uploads) { upload in
                            VStack(alignment: .leading, spacing: SyncTokens.space1) {
                                HStack {
                                    Text(upload.name).lineLimit(1)
                                    Spacer()
                                    Text(upload.statusLabel)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                }
                                ProgressView(value: upload.progress)
                            }
                            .padding(.top, SyncTokens.space3)
                        }
                    }
                }
                .padding(.horizontal, SyncTokens.space4)
                .padding(.top, SyncTokens.space4)
                .padding(.bottom, SyncTokens.space10 + SyncTokens.dockHeight)
            }

            if let toast {
                Text(toast)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, SyncTokens.dockHeight + SyncTokens.space6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                Task { await appState.uploadFiles(urls) }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let data = image.jpegData(compressionQuality: 0.85) {
                    let name = "photo-\(Int(Date().timeIntervalSince1970)).jpg"
                    Task { await appState.uploadImageData(data, name: name) }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { toast = nil }
        }
    }
}

struct UploadProgressItem: Identifiable {
    let id: UUID
    let name: String
    var progress: Double
    var statusLabel: String

    init(id: UUID = UUID(), name: String, progress: Double, statusLabel: String) {
        self.id = id
        self.name = name
        self.progress = progress
        self.statusLabel = statusLabel
    }
}
