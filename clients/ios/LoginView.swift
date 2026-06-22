// LoginView.swift
// PIN unlock screen — master PIN validated on server.

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState

    @State private var pin = ""
    @State private var serverURL = AppState.defaultServerURL
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.accent)
                Text("SyncBridge")
                    .font(.title2.bold())
                Text("Enter your PIN to unlock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)

            HStack {
                Image(systemName: "server.rack")
                    .foregroundStyle(.secondary)
                TextField("Server URL", text: $serverURL)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
            }

            SecureField("PIN", text: $pin)
                .textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif

            if let msg = appState.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Button {
                submit()
            } label: {
                Group {
                    if isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Unlock")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || pin.isEmpty)

            Text("Trusted devices skip this screen for 7 days.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear {
            appState.errorMessage = nil
            serverURL = appState.serverURL
        }
    }

    private func submit() {
        guard !pin.isEmpty else { return }
        isLoading = true
        appState.errorMessage = nil
        appState.serverURL = serverURL

        Task {
            defer { isLoading = false }
            await appState.unlock(pin: pin)
            pin = ""
        }
    }
}
