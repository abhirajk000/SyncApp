// LoginItemService.swift
// Controls whether SyncBridge launches automatically at login.
//
// macOS 13+ (Ventura):  SMAppService.mainApp — modern, user-facing, reversible.
// macOS 12 (Monterey):  SMLoginItemSetEnabled (legacy helper-app method).
//
// The newer API is strongly preferred; it shows the app in System Settings →
// General → Login Items so the user has full visibility and control.

import Foundation
import ServiceManagement
import os.log

private let logger = Logger(subsystem: "com.syncbridge", category: "LoginItem")

final class LoginItemService {

    static let shared = LoginItemService()
    private init() {}

    // MARK: – Query current state

    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        // On macOS 12, read from UserDefaults (best-effort).
        return UserDefaults.standard.bool(forKey: "launchAtLogin")
    }

    // MARK: – Toggle

    func setEnabled(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            modern(enable)
        } else {
            legacy(enable)
        }
    }

    // MARK: – Private: macOS 13+ (SMAppService)

    @available(macOS 13.0, *)
    private func modern(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
                logger.info("Registered as login item")
            } else {
                try SMAppService.mainApp.unregister()
                logger.info("Unregistered as login item")
            }
        } catch {
            logger.error("SMAppService error: \(error.localizedDescription)")
        }
    }

    // MARK: – Private: macOS 12 (SMLoginItemSetEnabled)

    private func legacy(_ enable: Bool) {
        // SMLoginItemSetEnabled requires a helper-app bundle embedded inside the
        // main app bundle.  For a self-contained distribution add a LoginHelper
        // target and pass its bundle identifier here.
        let bundleId = Bundle.main.bundleIdentifier.map { $0 + ".LoginHelper" } ?? ""
        let success = SMLoginItemSetEnabled(bundleId as CFString, enable)
        if !success {
            logger.warning("SMLoginItemSetEnabled returned false; ensure LoginHelper target exists")
        }
        UserDefaults.standard.set(enable, forKey: "launchAtLogin")
    }
}
