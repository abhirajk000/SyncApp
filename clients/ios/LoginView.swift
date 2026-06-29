// LoginView.swift — Web LoginPage parity

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState

    @State private var pin = ""
    @State private var loading = false

    var body: some View {
        ZStack {
            AppBackground()
            VStack {
                Spacer()
                LoginCard {
                    LoginHero()
                    LoginPinField(text: $pin, error: appState.errorMessage)
                    PrimaryButton(
                        text: loading ? "Unlocking…" : "Unlock",
                        loading: loading,
                        enabled: !pin.isEmpty
                    ) {
                        Task {
                            loading = true
                            appState.errorMessage = nil
                            await appState.unlock(pin: pin)
                            pin = ""
                            loading = false
                        }
                    }
                }
                .frame(maxWidth: 400)
                .padding(.horizontal, SyncTokens.space6)
                Spacer()
            }
        }
        .onAppear { appState.errorMessage = nil }
    }
}
