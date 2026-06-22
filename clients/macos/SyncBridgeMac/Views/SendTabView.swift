// SendTabView.swift — Send text and files (matches web SendPage).

import AppKit
import SwiftUI

struct SendTabView: View {

    @EnvironmentObject var appState: AppState
    @State private var text = ""
    @State private var sending = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: DS.Space.md) {
            Text("Send text, images, or files to your connected devices.")
                .font(DS.Font.body())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            AppCard {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    Text("Send Text")
                        .font(DS.Font.headline())
                    TextEditor(text: $text)
                        .font(DS.Font.body())
                        .frame(minHeight: 100, maxHeight: 140)
                        .scrollContentBackground(.hidden)
                        .padding(DS.Space.sm)
                        .background(Color(NSColor.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    if let error {
                        Text(error).font(DS.Font.label()).foregroundStyle(DS.Color.danger)
                    }
                    AppButton(title: sending ? "Sending…" : "Send", variant: .primary) {
                        Task { await sendText() }
                    }
                    .disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            AppButton(title: "Send File…", variant: .secondary) {
                openFilePicker()
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(DS.Space.md)
        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
            Task { @MainActor in
                var urls: [URL] = []
                for provider in providers {
                    if let url = try? await provider.loadItem(forTypeIdentifier: "public.file-url") as? URL {
                        urls.append(url)
                    } else if let url = await withCheckedContinuation({ (cont: CheckedContinuation<URL?, Never>) in
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in cont.resume(returning: url) }
                    }) {
                        urls.append(url)
                    }
                }
                if !urls.isEmpty { appState.uploadFiles(urls) }
            }
            return true
        }
    }

    private func sendText() async {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        sending = true
        error = nil
        defer { sending = false }
        do {
            _ = try await appState.authService.syncClipboard(contentType: "text/plain", content: content)
            text = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            appState.uploadFiles(panel.urls)
        }
    }
}
