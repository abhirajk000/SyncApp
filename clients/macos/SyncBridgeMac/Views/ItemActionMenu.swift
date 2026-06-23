// ItemActionMenu.swift — Download / Copy / Pin / Delete (matches web/Android).

import SwiftUI

struct ItemActionMenu: View {

    var showDownload: Bool = true
    var showCopy: Bool = true
    var showPin: Bool = true
    var showDelete: Bool = true
    var isPinned: Bool = false
    var onDownload: () -> Void = {}
    var onCopy: () -> Void = {}
    var onPin: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        // Native Menu escapes ScrollView / popover clipping (custom dropdown was hidden).
        Menu {
            if showDownload {
                Button(action: onDownload) {
                    Label("Download", systemImage: "arrow.down.to.line")
                }
            }
            if showCopy {
                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
            if showPin {
                Button(action: onPin) {
                    Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
                }
            }
            if showDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "xmark")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.55))
                .clipShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Actions")
    }
}

/// Clipboard row actions: Copy, Pin, Delete.
struct ClipboardItemActionMenu: View {

    @EnvironmentObject var appState: AppState
    let entry: ClipboardEntryResponse

    var body: some View {
        ItemActionMenu(
            showDownload: false,
            showCopy: true,
            showPin: true,
            showDelete: !entry.pinned,
            isPinned: entry.pinned,
            onCopy: { appState.copyToClipboard(entry) },
            onPin: { Task { await appState.pinClipboardEntry(entry, pinned: !entry.pinned) } },
            onDelete: { Task { await appState.deleteClipboardEntry(entry) } }
        )
    }
}
