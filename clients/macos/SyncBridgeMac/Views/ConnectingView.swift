// ConnectingView.swift — Native connect (no PIN — web-only)

import AppKit
import SwiftUI

struct ConnectingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appPresentationMode) private var presentationMode
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LiquidBackground()
            VStack {
                Spacer()
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
                    Text("SyncBridge")
                        .font(SyncFont.title2xl())
                    Text("Instant clipboard sync")
                        .font(SyncFont.bodySm())
                        .foregroundStyle(DS.Color.muted)

                    if case .loggingIn = appState.authState {
                        ProgressView()
                            .controlSize(.regular)
                        Text("Connecting to sync.abhiraj.xyz…")
                            .font(SyncFont.bodySm())
                            .foregroundStyle(DS.Color.muted)
                    } else if let error = appState.errorMessage {
                        Text(error)
                            .font(SyncFont.bodySm())
                            .foregroundStyle(DS.Color.danger)
                            .multilineTextAlignment(.center)
                        AppButton(title: "Retry", variant: .primary) {
                            Task { await appState.restoreSession() }
                        }
                    } else {
                        AppButton(title: "Connect", variant: .primary) {
                            Task { await appState.restoreSession() }
                        }
                    }
                }
                .padding(DS.Space.xl)
                .adaptiveGlassCard(cornerRadius: DS.Radius.card)
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
        .onAppear {
            appState.errorMessage = nil
            Task { await appState.restoreSession() }
        }
    }
}
