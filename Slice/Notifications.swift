import Foundation
import UserNotifications
import os

/// Posts a system notification (banner + sound) when a Pomodoro phase ends.
/// A case-less `enum` is Swift's idiom for a namespace: nothing to instantiate,
/// no state to hold.
enum Notifications {
    /// `os.Logger` writes to the unified system log. Read it with
    /// `log show --predicate 'subsystem == "com.rezaahmadn.Slice"'`.
    private static let logger = Logger(subsystem: "com.rezaahmadn.Slice", category: "Notifications")

    /// Asks macOS for permission. The system shows its prompt only the first time;
    /// later calls return the remembered answer immediately.
    /// Called when the user first presses Start, so the prompt has context.
    static func requestAuthorization() async {
        do {
            // `.alert` = banner, `.sound` = the ding. No `.badge`: there is no Dock icon.
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            // `.notice` (not `.info`) so the line is persisted and `log show` can find it.
            logger.notice("Notification permission granted: \(granted, privacy: .public)")
        } catch {
            logger.error("Notification permission request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Title and body for the phase that just ended. Pure, so it is unit-tested.
    static func content(for finished: PomodoroTimer.Phase) -> (title: String, body: String) {
        switch finished {
        case .work: ("Work done", "Take a break.")
        case .shortBreak: ("Break over", "Back to work when you're ready.")
        }
    }

    /// Delivers the notification now.
    static func post(for finished: PomodoroTimer.Phase) {
        let (title, body) = content(for: finished)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // `trigger: nil` means "deliver immediately". A fresh UUID per request so
        // two notifications never replace each other.
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("Failed to post notification: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.notice("Posted notification: \(title, privacy: .public)")
            }
        }
    }
}
