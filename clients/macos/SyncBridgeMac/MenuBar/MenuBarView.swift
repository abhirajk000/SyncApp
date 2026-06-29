// MenuBarView.swift
// The SwiftUI view rendered inside the NSPopover attached to the menu bar icon.
//
// Layout:
//   ┌──────────────────────────────────────┐
//   │  ● SyncBridge   [status]        [⋯]  │  header
//   ├──────────────────────────────────────┤
//   │  [Home][Pinned]  (Send)  [Files][⚙]│  dock nav (web style, top)
//   ├──────────────────────────────────────┤
//   │           tab content                │
//   └──────────────────────────────────────┘

import AppKit
import SwiftUI

struct MenuBarView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var localSendManager: LocalSendManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appPresentationMode) private var presentationMode
    @State private var selectedTab: AppNavTab = .clipboard

    private var isWindow: Bool { presentationMode == .window }

    var body: some View {
        ZStack {
                Group {
                    if case .loggedIn = appState.authState {
                        mainContent
                    } else {
                        ConnectingView()
                    }
                }
                .frame(
                    width: isWindow ? nil : MenuBarLayout.width,
                    height: isWindow ? nil : MenuBarLayout.popoverContentHeight
                )
                .frame(
                    maxWidth: isWindow ? .infinity : nil,
                    maxHeight: isWindow ? .infinity : nil
                )
                .clipped()

                if let entry = appState.latestClipboardPopup {
                    LatestClipboardPopupView(entry: entry) {
                        appState.dismissLatestClipboardPopup()
                    }
                    .environmentObject(appState)
                    .frame(
                        width: isWindow ? nil : MenuBarLayout.width,
                        height: isWindow ? nil : MenuBarLayout.popoverContentHeight
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
            }
        .frame(
            minWidth: isWindow ? MenuBarLayout.windowMinWidth : MenuBarLayout.width,
            minHeight: isWindow ? MenuBarLayout.windowMinHeight : MenuBarLayout.height
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: – Main content (authenticated)

    private var mainContent: some View {
        AppShell(
            selectedTab: selectedTab,
            connected: appState.syncStatus == .connected,
            refreshing: appState.isRefreshing,
            onRefresh: { Task { await appState.refreshHome() } },
            onNavigate: { tab in
                withAnimation(.easeOut(duration: DS.Duration.normal)) {
                    selectedTab = tab
                }
            },
            content: tabContent
        )
        .overlay(alignment: .topTrailing) {
            macMenuButton
                .padding(.trailing, DS.Space.md)
                .padding(.top, 6)
        }
    }

    private var macMenuButton: some View {
        Menu {
            Button { appState.requestOpenMainWindow() } label: {
                Label("Open App Window", systemImage: "macwindow")
            }
            Divider()
            Button { Task { await appState.initiatePairing() } } label: {
                Label("Pair device", systemImage: "qrcode.viewfinder")
            }
            Divider()
            Button(role: .destructive) { Task { await appState.logout() } } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
    @ViewBuilder
    private func tabContent(_ tab: AppNavTab) -> some View {
        switch tab {
        case .cloudSend:
            SendTabView()
        case .localSend:
            LocalSendView()
                .environmentObject(localSendManager)
        case .clipboard:
            ClipboardHubView()
        case .files:
            FilesView()
        case .settings:
            SettingsView(embedded: true)
        }
    }
}

// ── FilesView ─────────────────────────────────────────────────────────────────

struct FilesView: View {
    @EnvironmentObject var appState: AppState
    @State private var fileTab: FileTab = .temporary

    private enum FileTab: String, CaseIterable {
        case temporary = "Temporary"
        case pinned = "Pinned"
    }

    var body: some View {
        VStack(spacing: 0) {
            if !appState.activeTransfers.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.activeTransfers) { item in
                            TransferRowView(item: item)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 120)
                Divider()
            }

            Picker("Files", selection: $fileTab) {
                ForEach(FileTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.sm)

            let temporary = appState.files.filter { !$0.isPinned }
            let pinned = appState.files.filter { $0.isPinned }
            let showing = fileTab == .temporary ? temporary : pinned

            if showing.isEmpty {
                emptyState
            } else if fileTab == .temporary {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 88), spacing: DS.Space.sm)],
                        spacing: DS.Space.sm
                    ) {
                        ForEach(temporary) { file in
                            FileGridItemView(file: file)
                        }
                    }
                    .padding(DS.Space.md)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await appState.refreshFiles() }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(pinned) { file in
                            FileRowView(file: file)
                            Divider().opacity(0.35)
                        }
                    }
                    .padding(.horizontal, DS.Space.sm)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await appState.refreshFiles() }
            }

            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        AppEmptyState(
            illustration: .files,
            title: fileTab == .pinned ? "No pinned files" : "No files yet",
            description: fileTab == .pinned
                ? "Pin files to keep them across devices."
                : "Receive files via Local Send or from cloud sync on other devices.",
            actionTitle: fileTab == .temporary ? "Send File…" : nil,
            action: fileTab == .temporary ? openFilePicker : nil
        )
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            panel.urls.forEach { appState.uploadFile($0) }
        }
    }
}

// ── FileRowView ───────────────────────────────────────────────────────────────

struct FileRowView: View {
    @EnvironmentObject var appState: AppState
    let file: FileResponse

    private var ready: Bool { file.status == "ready" }
    private var canCopy: Bool {
        ready && (file.mimeType.hasPrefix("image/") || file.mimeType.hasPrefix("text/") || file.mimeType == "application/json")
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: fileIcon(file.mimeType))
                .frame(width: 24)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(formattedSize(file.totalSize))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TransferBadgeView(transferMode: file.transferMode)
            }

            Spacer()

            ItemActionMenu(
                showDownload: ready,
                showCopy: canCopy,
                showPin: true,
                showDelete: !file.isPinned,
                isPinned: file.isPinned,
                onDownload: { appState.downloadFile(file) },
                onCopy: { Task { await appState.copyFileToClipboard(file) } },
                onPin: { Task { await appState.pinFile(file, pinned: !file.isPinned) } },
                onDelete: { Task { await appState.deleteFile(file) } }
            )
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.sm)
        .background(Color.clear)
    }
}

// ── TransferRowView ───────────────────────────────────────────────────────────

struct TransferRowView: View {
    let item: TransferItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.status == .uploading ? "arrow.up.circle" : "arrow.down.circle")
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline).lineLimit(1)
                ProgressView(value: item.progress)
                    .progressViewStyle(.linear)
            }
            Text("\(Int(item.progress * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// ── DevicesView ───────────────────────────────────────────────────────────────

struct DevicesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(appState.devices) { device in
                    DeviceRowView(device: device)
                    Divider()
                }
            }
        }
        .overlay {
            if appState.devices.isEmpty {
                AppEmptyState(
                    illustration: .devices,
                    title: "No paired devices",
                    description: "Pair another phone or computer to sync clipboard and files.",
                    actionTitle: "Pair a Device",
                    action: { Task { await appState.initiatePairing() } }
                )
            }
        }
        .sheet(isPresented: $appState.isPairingActive) {
            PairingView()
                .environmentObject(appState)
        }
        .task { await appState.refreshDevices() }
    }
}

// ── DeviceRowView ─────────────────────────────────────────────────────────────

struct DeviceRowView: View {
    @EnvironmentObject var appState: AppState
    let device: DeviceResponse

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: platformIcon(device.platform))
                .frame(width: 24)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.subheadline)
            }

            Spacer()

            if device.id != KeychainService.shared.deviceId {
                Button(role: .destructive) {
                    Task { try? await appState.authService.revokeDevice(id: device.id) }
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Revoke device")
            } else {
                Text("This device")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

private func platformIcon(_ platform: String) -> String {
    switch platform {
    case "macos":   return "desktopcomputer"
    case "ios":     return "iphone"
    case "android": return "candybarphone"
    default:        return "laptop"
    }
}

private func fileIcon(_ mimeType: String) -> String {
    switch mimeType {
    case let t where t.hasPrefix("image/"):    return "photo"
    case let t where t.hasPrefix("video/"):    return "film"
    case "application/pdf":                    return "doc.richtext"
    case "application/zip", "application/gzip": return "archivebox"
    default:                                   return "doc"
    }
}

private func formattedSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}
