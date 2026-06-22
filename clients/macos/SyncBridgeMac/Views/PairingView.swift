// PairingView.swift — DesignSystem QR pairing sheet

import SwiftUI
import CoreImage.CIFilterBuiltins

struct PairingView: View {

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: DS.Space.xl) {
            Text("Pair a New Device")
                .font(DS.Font.headline())

            Text("Scan this QR code from the SyncBridge app on your other device.")
                .font(DS.Font.caption())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            AppCard {
                if let code = appState.pairingCode {
                    VStack(spacing: DS.Space.lg) {
                        qrCodeImage(for: code)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .padding(DS.Space.md)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

                        Text("Code: \(code)")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)

                        if let expiresAt = appState.pairingExpiresAt {
                            Text("Expires at \(expiresAt)")
                                .font(DS.Font.caption())
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(spacing: DS.Space.md) {
                        ProgressView()
                        Text("Generating code…")
                            .font(DS.Font.caption())
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 200, height: 200)
                }
            }

            HStack(spacing: DS.Space.sm) {
                AppButton(title: "Refresh", variant: .ghost) {
                    Task { await appState.initiatePairing() }
                }
                .frame(maxWidth: .infinity)
                AppButton(title: "Done") {
                    appState.isPairingActive = false
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(DS.Space.xl)
        .frame(width: 320)
        .task {
            if appState.pairingCode == nil {
                await appState.initiatePairing()
            }
        }
    }

    private func qrCodeImage(for string: String) -> Image {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else {
            return Image(systemName: "qrcode")
        }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return Image(systemName: "qrcode")
        }
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 200, height: 200))
        return Image(nsImage: nsImage)
    }
}
