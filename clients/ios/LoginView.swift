// LoginView.swift — Premium

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var pin = ""

    var body: some View {
        ZStack {
            LiquidBackground()
            VStack(spacing: DS.Space.xl) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .padding(DS.Space.sm)
                    .background(DS.Color.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))

                Text("SyncBridge").font(DS.Font.display())
                Text("Enter your PIN to unlock").font(DS.Font.caption()).foregroundStyle(.secondary)

                AppCard {
                    VStack(spacing: DS.Space.lg) {
                        PremiumTextField(text: $pin, secure: true)
                        if let err = appState.errorMessage {
                            Text(err).font(DS.Font.caption()).foregroundStyle(DS.Color.danger)
                        }
                        AppButton(title: "Unlock", disabled: pin.isEmpty) {
                            Task { await appState.unlock(pin: pin) }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, DS.Space.xxl)
        }
        .padding()
    }
}
