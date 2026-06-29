// LoginView.swift — Web LoginPage parity (menu bar + window)

import AppKit
import SwiftUI

struct LoginView: View {

    @EnvironmentObject var appState: AppState
    @Environment(\.appPresentationMode) private var presentationMode
    @Environment(\.colorScheme) private var colorScheme

    @State private var pin = ""
    @State private var isLoading = false

    var body: some View {
        ZStack {
            LiquidBackground()
            VStack {
                Spacer()
                loginCard
                    .frame(maxWidth: 400)
                    .padding(.horizontal, DS.Space.xl)

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
                    .foregroundStyle(DS.Color.primaryAdaptive(colorScheme))
                    .padding(.horizontal, DS.Space.xl)
                    .padding(.top, DS.Space.md)
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { appState.errorMessage = nil }
    }

    private var loginCard: some View {
        VStack(spacing: DS.Space.lg) {
            loginHero
            loginPinField
            AppButton(
                title: isLoading ? "Unlocking…" : "Unlock",
                disabled: isLoading || pin.isEmpty
            ) {
                submit()
            }
            .frame(height: 56)
        }
        .padding(.horizontal, DS.Space.xl)
        .padding(.vertical, DS.Space.xxl)
        .frame(maxWidth: .infinity)
        .background(DS.Color.cardAdaptive(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(DS.Color.borderAdaptive(colorScheme).opacity(0.55), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.55 : 0.18),
            radius: 24,
            y: 12
        )
    }

    private var loginHero: some View {
        VStack(spacing: DS.Space.lg) {
            Image(nsImage: NSImage(named: "AppLogo") ?? NSImage())
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .frame(width: 64, height: 64)
                .background(
                    LinearGradient(
                        colors: [DS.Color.primary.opacity(0.12), Color.white.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .stroke(Color.white.opacity(0.85), lineWidth: 1)
                )
                .shadow(color: DS.Color.primary.opacity(0.15), radius: 12, y: 6)

            Text("SyncBridge")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .tracking(-0.3)
                .foregroundStyle(DS.Color.textAdaptive(colorScheme))

            Text("Enter your PIN to unlock")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(DS.Color.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, DS.Space.sm)
    }

    private var loginPinField: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            SecureField("PIN", text: $pin)
                .textFieldStyle(.plain)
                .font(DS.Font.body())
                .padding(.horizontal, DS.Space.lg)
                .padding(.vertical, DS.Space.md)
                .background(DS.Color.cardAdaptive(colorScheme), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(
                            appState.errorMessage != nil ? DS.Color.danger : DS.Color.borderAdaptive(colorScheme).opacity(0.45),
                            lineWidth: 1
                        )
                )
                .onSubmit { submit() }

            if let msg = appState.errorMessage {
                Text(msg)
                    .font(DS.Font.caption())
                    .foregroundStyle(DS.Color.danger)
            }
        }
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
