// SyncBridgeMacApp.swift
// @main entry point.
//
// The app is a pure menu-bar application:
//   • LSUIElement = YES in Info.plist hides it from the Dock and App Switcher.
//   • The only visible surface is the NSStatusItem + NSPopover.
//   • The Settings scene provides a standard Cmd+, preferences window.

import SwiftUI

@main
struct SyncBridgeMacApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Suppress the default empty window.
        // The Settings scene is opened via Cmd+, or the menu bar menu item.
        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
        }
    }
}
