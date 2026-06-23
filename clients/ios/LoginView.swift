// LoginView.swift — Matches Android LoginScreen.kt

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    @State private var pin = ""
    @State private var loading = false
    @State private var showQRScanner = false

    var body: some View {
        ZStack {
            AppBackground()
            VStack {
                Spacer()
                AppCard {
                    VStack(spacing: SyncTokens.space4) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 52, height: 52)
                            .frame(width: 72, height: 72)
                            .background(SyncTokens.teal.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusLg))

                        Text("SyncBridge")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Enter your PIN to unlock")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(AppSurfaces.onSurfaceVariant(colorScheme))
                            .multilineTextAlignment(.center)

                        SecureField("PIN", text: $pin)
                            .keyboardType(.numberPad)
                            .padding(SyncTokens.space3)
                            .background(AppSurfaces.surfaceVariant(colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: SyncTokens.radiusMd))
                            .overlay(
                                RoundedRectangle(cornerRadius: SyncTokens.radiusMd)
                                    .stroke(AppSurfaces.cardBorder(colorScheme), lineWidth: 1)
                            )

                        if let err = appState.errorMessage {
                            Text(err)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(SyncTokens.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        PrimaryButton(
                            text: loading ? "Unlocking…" : "Unlock",
                            loading: loading,
                            enabled: !pin.isEmpty
                        ) {
                            Task {
                                loading = true
                                await appState.unlock(pin: pin)
                                pin = ""
                                loading = false
                            }
                        }

                        VStack(spacing: SyncTokens.space1) {
                            Divider().overlay(SyncTokens.cardBorder)
                        }

                        Button {
                            showQRScanner = true
                        } label: {
                            HStack(spacing: SyncTokens.space2) {
                                Image(systemName: "qrcode.viewfinder")
                                Text("Scan QR to pair")
                            }
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                        }
                        .buttonStyle(.bordered)
                        .disabled(loading)
                    }
                }
                .frame(maxWidth: 400)
                .padding(.horizontal, SyncTokens.space6)
                Spacer()
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerSheet { raw in
                Task {
                    loading = true
                    await appState.pairFromQr(raw)
                    loading = false
                }
            }
        }
    }
}
