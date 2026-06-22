// AppDelegate.swift
// Owns the NSStatusItem (menu bar icon + popover) and application lifecycle.

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    // ── Public ────────────────────────────────────────────────────────────────

    let appState = AppState()

    // ── Private ───────────────────────────────────────────────────────────────

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    // MARK: – Application lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the Dock icon programmatically (belt + suspenders with LSUIElement).
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        setupEventMonitor()

        // Start background services if already authenticated.
        Task { @MainActor in
            self.appState.onAppear()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.stopServices()
    }

    // MARK: – Status item (menu bar icon)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "SyncBridge")
            button.image?.isTemplate = true   // respects dark/light mode automatically
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Observe sync status to update the icon.
        Task { @MainActor [weak self] in
            for await status in self?.appState.$syncStatus.values ?? AsyncStream { _ in } {
                self?.updateStatusIcon(status)
            }
        }
    }

    private func updateStatusIcon(_ status: SyncStatus) {
        guard let button = statusItem?.button else { return }
        let name: String
        switch status {
        case .disconnected:         name = "arrow.triangle.2.circlepath"
        case .connecting:           name = "arrow.clockwise"
        case .connected, .syncing:  name = "checkmark.circle"
        case .error:                name = "exclamationmark.circle"
        }
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: "SyncBridge")
        button.image?.isTemplate = true
    }

    // MARK: – Popover

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(appState)
        )
        self.popover = popover
    }

    @objc private func togglePopover(sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        // Right-click → native context menu.
        if event.type == .rightMouseUp {
            showContextMenu()
            return
        }

        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open SyncBridge", action: #selector(openPopover), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SyncBridge", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openPopover() {
        guard let popover, let button = statusItem?.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func openSettings() {
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: – Click-outside dismissal

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }
}
