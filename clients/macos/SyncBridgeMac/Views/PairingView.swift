// PairingView.swift
// Displays a QR code that other devices can scan to pair with this account.
// Uses CoreImage to generate the QR code — no third-party libraries.

import SwiftUI
import CoreImage.CIFilterBuiltins

struct PairingView: View {

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Pair a New Device")
                .font(.headline)

            Text("Scan this QR code from the SyncBridge app on your other device.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let code = appState.pairingCode {
                qrCodeImage(for: code)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)

                Text("Code: **\(code)**")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)

                if let expiresAt = appState.pairingExpiresAt {
                    Text("Expires at \(expiresAt)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView("Generating code…")
                    .frame(width: 200, height: 200)
            }

            HStack {
                Button("Refresh") {
                    Task { await appState.initiatePairing() }
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    appState.isPairingActive = false
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 320)
        .task {
            if appState.pairingCode == nil {
                await appState.initiatePairing()
            }
        }
    }

    // MARK: – QR code generation

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
