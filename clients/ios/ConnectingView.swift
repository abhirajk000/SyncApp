// ConnectingView.swift — Native connect (no PIN — web-only)

import SwiftUI

struct ConnectingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            AppBackground()
            VStack {
                Spacer()
                LoginCard {
                    LoginHero()
                    if appState.isConnecting {
                        ProgressView()
                            .tint(SyncTokens.teal)
                        Text("Connecting to sync.abhiraj.xyz…")
                            .font(SyncFont.bodySm())
                            .foregroundStyle(SyncTokens.slateSecondary)
                    } else if let error = appState.errorMessage {
                        Text(error)
                            .font(SyncFont.bodySm())
                            .foregroundStyle(SyncTokens.danger)
                            .multilineTextAlignment(.center)
                        PrimaryButton(text: "Retry") {
                            Task { await appState.ensureAuthenticated() }
                        }
                    } else {
                        PrimaryButton(text: "Connect") {
                            Task { await appState.ensureAuthenticated() }
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
