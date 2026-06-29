// AppDelegate.swift
// Owns the NSStatusItem (menu bar icon + popover) and application lifecycle.

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // ── Public ────────────────────────────────────────────────────────────────

    let appState = AppState()
    let localSendManager = LocalSendManager()

    // ── Private ───────────────────────────────────────────────────────────────

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsWindow: NSWindow?
    private var mainWindow: NSWindow?
    private var mainWindowDelegate: MainWindowDelegate?
    private var eventMonitor: Any?

    // MARK: – Application lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the Dock icon programmatically (belt + suspenders with LSUIElement).
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        setupApplicationIcon()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .syncBridgeOpenSettings,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openMainWindow),
            name: .syncBridgeOpenMainWindow,
            object: nil
        )

        Task { @MainActor in
            self.appState.openMainWindowHandler = { [weak self] in
                self?.openMainWindow()
            }
            self.localSendManager.start()
            self.appState.onAppear()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        localSendManager.stop()
        appState.stopServices()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        localSendManager.start()
        appState.networkManager.setUiActive(true)
    }

    func applicationDidResignActive(_ notification: Notification) {
        localSendManager.stop()
        appState.networkManager.setUiActive(false)
    }

    // MARK: – Status item (menu bar icon)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = loadMenuBarIcon()
            button.image?.isTemplate = false
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func loadMenuBarIcon() -> NSImage? {
        let image: NSImage? = {
            if let named = NSImage(named: "MenuBarIcon") { return named }
            if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") {
                return NSImage(contentsOf: url)
            }
            return nil
        }()
        if let image {
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        return NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "SyncBridge")
    }

    // MARK: – Popover

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: MenuBarLayout.width, height: MenuBarLayout.height)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(appState)
                .environmentObject(localSendManager)
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
        menu.addItem(NSMenuItem(title: "Open Menu Bar Panel", action: #selector(openPopover), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open App Window", action: #selector(openMainWindow), keyEquivalent: "o"))
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

    @objc private func openMainWindow() {
        popover?.performClose(nil)

        if let mainWindow {
            NSApp.setActivationPolicy(.regular)
            mainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(appState)
                .environmentObject(localSendManager)
                .appPresentationMode(.window)
        )
        let window = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0,
                width: MenuBarLayout.windowDefaultWidth,
                height: MenuBarLayout.windowDefaultHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SyncBridge"
        window.contentViewController = hosting
        window.minSize = NSSize(width: MenuBarLayout.windowMinWidth, height: MenuBarLayout.windowMinHeight)
        window.isReleasedWhenClosed = false
        window.center()

        let delegate = MainWindowDelegate { [weak self] in
            guard let self else { return }
            self.mainWindow = nil
            self.mainWindowDelegate = nil
            if self.popover?.isShown != true {
                NSApp.setActivationPolicy(.accessory)
            }
        }
        window.delegate = delegate
        mainWindowDelegate = delegate
        mainWindow = window

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettings() {
        popover?.performClose(nil)

        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(
            rootView: SettingsView()
                .environmentObject(appState)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "SyncBridge Settings"
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupApplicationIcon() {
        if let icon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = icon
            return
        }
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: url) else { return }
        NSApp.applicationIconImage = icon
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

extension Notification.Name {
    static let syncBridgeOpenSettings = Notification.Name("SyncBridgeOpenSettings")
    static let syncBridgeOpenMainWindow = Notification.Name("SyncBridgeOpenMainWindow")
}

private final class MainWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
