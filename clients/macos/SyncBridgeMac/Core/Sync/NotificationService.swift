// NotificationService.swift
// macOS user notifications for remote clipboard updates.

import Foundation
import UserNotifications

enum NotificationService {

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notifyClipboardUpdated(preview: String) {
        let content = UNMutableNotificationContent()
        content.title = "Clipboard Updated"
        let trimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = trimmed.count > 120 ? String(trimmed.prefix(120)) + "…" : trimmed
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
