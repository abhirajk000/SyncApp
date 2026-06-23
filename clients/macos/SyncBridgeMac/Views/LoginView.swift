// LoginView.swift — Premium unlock screen

import AppKit
import SwiftUI

struct LoginView: View {

    @EnvironmentObject var appState: AppState
    @Environment(\.appPresentationMode) private var presentationMode

    @State private var pin = ""
    @State private var isLoading = false

    var body: some View {
        ZStack {
            LiquidBackground()
            VStack(spacing: DS.Space.xl) {
                VStack(spacing: DS.Space.sm) {
                    Image(nsImage: NSImage(named: "AppLogo") ?? NSImage())
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .padding(DS.Space.sm)
                        .background(DS.Color.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))

                    Text("SyncBridge")
                        .font(DS.Font.display())
                    Text("Enter your PIN to unlock")
                        .font(DS.Font.caption())
                        .foregroundStyle(.secondary)
                }

                AppCard {
                    VStack(spacing: DS.Space.lg) {
                        PremiumTextField(text: $pin, secure: true)
                        if let msg = appState.errorMessage {
                            Text(msg).font(DS.Font.caption()).foregroundStyle(DS.Color.danger)
                        }
                        AppButton(title: isLoading ? "Unlocking…" : "Unlock", disabled: isLoading || pin.isEmpty) {
                            submit()
                        }
                    }
                }
                .padding(.horizontal, DS.Space.lg)

                if presentationMode == .popover {
                    Button {
                        appState.requestOpenMainWindow()
                    } label: {
                        Label("Open as App", systemImage: "macwindow")
                            .font(DS.Font.body().weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Space.sm)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.Color.primary)
                    .padding(.horizontal, DS.Space.lg)
                }

                Spacer()
            }
            .padding(.top, DS.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appState.errorMessage = nil }
    }

    private func submit() {
        guard !pin.isEmpty else { return }
        isLoading = true
        appState.errorMessage = nil
        Task {
            defer { isLoading = false }
            await appState.unlock(pin: pin)
            pin = ""
        }
    }
}
