// ItemActionMenu.swift — Download / Copy / Pin / Delete (native Menu — works in scroll views).

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
        Menu {
            if showDownload {
                Button("Download", systemImage: "arrow.down.to.line", action: onDownload)
            }
            if showCopy {
                Button("Copy", systemImage: "doc.on.doc", action: onCopy)
            }
            if showPin {
                Button(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin", action: onPin)
            }
            if showDelete {
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
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
        .fixedSize()
    }
}

/// Clipboard row actions on home — Copy, Pin, Delete (matches macOS / Android).
struct ClipboardItemActionMenu: View {
    @EnvironmentObject var appState: AppState
    let entry: ClipboardEntry

    var body: some View {
        ItemActionMenu(
            showDownload: false,
            showCopy: true,
            showPin: true,
            showDelete: !entry.pinned,
            isPinned: entry.pinned,
            onCopy: { appState.copyEntry(entry) },
            onPin: { Task { await appState.pinClipboard(entry, pinned: !entry.pinned) } },
            onDelete: { Task { await appState.deleteClipboard(entry) } }
        )
    }
}
