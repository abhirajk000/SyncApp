// LoginView.swift
// PIN unlock screen — master PIN is validated on the server.

import SwiftUI

struct LoginView: View {

    @EnvironmentObject var appState: AppState

    @State private var pin = ""
    @State private var serverURL = KeychainService.shared.serverURL
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("SyncBridge")
                    .font(.title2.bold())
                Text("Enter your PIN to unlock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)

            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.secondary)
                TextField("Server URL", text: $serverURL)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        KeychainService.shared.serverURL = serverURL
                        APIClient.shared.baseURL = serverURL
                    }
            }

            SecureField("PIN", text: $pin)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)

            if let msg = appState.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)
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
            .keyboardShortcut(.return)

            Text("Trusted devices skip this screen for 7 days.")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear { appState.errorMessage = nil }
    }

    private func submit() {
        guard !pin.isEmpty else { return }
        isLoading = true
        appState.errorMessage = nil
        KeychainService.shared.serverURL = serverURL
        APIClient.shared.baseURL = serverURL

        Task {
            defer { isLoading = false }
            await appState.unlock(pin: pin)
            pin = ""
        }
    }
}
