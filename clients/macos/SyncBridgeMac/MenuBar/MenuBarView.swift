// MenuBarView.swift
// The SwiftUI view rendered inside the NSPopover attached to the menu bar icon.
//
// Layout:
//   ┌──────────────────────────────────────┐
//   │  ● SyncBridge   [status]    [⚙]  [→] │  header
//   ├──────────────────────────────────────┤
//   │  📋 Clipboard  /  📁 Files  / 💻 Dev │  tab bar
//   ├──────────────────────────────────────┤
//   │                                      │
//   │           tab content                │  340 × 400
//   │                                      │
//   └──────────────────────────────────────┘

import AppKit
import SwiftUI

struct MenuBarView: View {

    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .clipboard

    enum Tab: String, CaseIterable {
        case clipboard = "Clipboard"
        case pinned    = "Pinned"
        case send      = "Send"
        case files     = "Files"

        var icon: String {
            switch self {
            case .clipboard: return "doc.on.clipboard"
            case .pinned:    return "pin.fill"
            case .send:      return "paperplane.fill"
            case .files:     return "folder.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            Group {
                if case .loggedOut = appState.authState {
                    LoginView()
                        .frame(width: 340, height: 520)
                } else {
                    mainContent
                        .frame(width: 340, height: 520)
                }
            }

            if let entry = appState.latestClipboardPopup {
                LatestClipboardPopupView(entry: entry) {
                    appState.dismissLatestClipboardPopup()
                }
            }
        }
    }

    // MARK: – Main content (authenticated)

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabBar
            Divider()
            tabContent
        }
    }

    // MARK: – Header

    private var header: some View {
        HStack(spacing: DS.Space.sm) {
            Image(nsImage: NSImage(named: "AppLogo") ?? NSImage())
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)

            Text("SyncBridge")
                .font(DS.Font.headline())

            Spacer()

            statusBadge

            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Image(systemName: "gearshape")
                    .help("Settings")
            }
            .buttonStyle(.plain)

            Button {
                Task { await appState.initiatePairing() }
            } label: {
                Image(systemName: "qrcode.viewfinder")
                    .help("Pair a new device")
            }
            .buttonStyle(.plain)

            Button {
                Task { await appState.logout() }
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .help("Sign out")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.md)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch appState.syncStatus {
        case .connected:
            AppBadge(status: .connected, label: "Synced")
        case .syncing:
            AppBadge(status: .syncing)
        case .connecting:
            AppBadge(status: .syncing, label: "Connecting")
        case .disconnected:
            AppBadge(status: .offline)
        case .error:
            AppBadge(status: .disconnected, label: "Error")
        }
    }

    // MARK: – Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: DS.Space.xs) {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                            .font(DS.Font.label())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Space.sm)
                    .foregroundStyle(selectedTab == tab ? DS.Color.primary : .secondary)
                    .background(selectedTab == tab
                        ? DS.Color.primary.opacity(0.1)
                        : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: – Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .clipboard:
            HomeView(onSeeAllFiles: { selectedTab = .files })
        case .pinned:
            PinnedClipboardView()
        case .send:
            SendTabView()
        case .files:
            FilesView()
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: DS.Space.md)], spacing: DS.Space.md) {
                        ForEach(temporary) { file in
                            FileGridItemView(file: file)
                        }
                    }
                    .padding(DS.Space.md)
                }
                .task { await appState.refreshFiles() }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(pinned) { file in
                            FileRowView(file: file)
                            Divider()
                        }
                    }
                }
                .task { await appState.refreshFiles() }
            }

            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        AppEmptyState(
            icon: "folder.badge.plus",
            title: fileTab == .pinned ? "No pinned files" : "No files yet",
            description: fileTab == .pinned
                ? "Pin files to keep them across devices."
                : "Send files from the Send tab or another device.",
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
            }

            Spacer()

            Button {
                Task { await appState.pinFile(file, pinned: !file.isPinned) }
            } label: {
                Image(systemName: file.isPinned ? "pin.slash" : "pin")
                    .foregroundColor(file.isPinned ? .orange : .secondary)
            }
            .buttonStyle(.plain)

            if file.status == "ready" {
                Button {
                    appState.downloadFile(file)
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
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
                    icon: "desktopcomputer.and.arrow.down",
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
                .foregroundColor(device.trusted ? .accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.subheadline)
                HStack(spacing: 4) {
                    if device.trusted {
                        Label("Trusted", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            if device.id != KeychainService.shared.deviceId {
                Button(role: .destructive) {
                    Task { await appState.authService.revokeDevice(id: device.id) }
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
