import AppKit
import SwiftUI
import os

/// The "alarm" alert style: a floating window above everything, on every Space,
/// plus a looping sound, until the user clicks Dismiss. Not a notification, so
/// Focus modes cannot hide it.
///
/// `@MainActor` because it owns AppKit objects; a case-less enum with static
/// state is enough since there is only ever one alarm at a time.
@MainActor
enum Alarm {
    private static let logger = Logger(subsystem: "com.rezaahmadn.Slice", category: "Alarm")

    /// Stop the sound after this long even if nobody clicks Dismiss.
    /// The window stays until dismissed.
    static let soundCutoff: TimeInterval = 120

    /// Name of a system sound in /System/Library/Sounds.
    static let soundName = "Glass"

    private static var panel: NSPanel?
    private static var sound: NSSound?
    private static var cutoffTask: Task<Void, Never>?

    /// Shows the window and starts the looping sound for the phase that ended.
    static func show(for finished: PomodoroTimer.Phase) {
        dismiss()   // one alarm at a time
        let (title, message) = Notifications.content(for: finished)

        let view = AlarmView(title: title, message: message) { dismiss() }
        // `NSHostingView` wraps a SwiftUI view so AppKit windows can show it.
        let hosting = NSHostingView(rootView: view)
        // Give the panel a real size up front; a SwiftUI hosting view has no
        // fitting size until it is inside a window, and a zero-size window is invisible.
        let size = NSSize(width: 360, height: 260)
        hosting.frame = NSRect(origin: .zero, size: size)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.contentView = hosting
        // `.floating` sits above normal windows; the collection behavior makes it
        // follow you to every Space and over full-screen apps.
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        // Panels hide when their app deactivates — which, for a menu bar app, is
        // always. Turn that off or the alarm vanishes the instant it appears.
        panel.hidesOnDeactivate = false
        panel.center()
        panel.orderFrontRegardless()
        NSApp.activate()
        Self.panel = panel

        if let s = NSSound(named: NSSound.Name(soundName)) {
            s.loops = true
            s.play()
            sound = s
        }
        cutoffTask = Task {
            try? await Task.sleep(for: .seconds(soundCutoff))
            sound?.stop()
        }
        logger.notice("Alarm shown: \(title, privacy: .public)")
    }

    /// Stops the sound and closes the window. Safe to call when nothing is showing.
    static func dismiss() {
        cutoffTask?.cancel()
        cutoffTask = nil
        sound?.stop()
        sound = nil
        if panel != nil {
            logger.notice("Alarm dismissed")
        }
        panel?.close()
        panel = nil
    }
}
