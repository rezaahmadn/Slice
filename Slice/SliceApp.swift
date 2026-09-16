import SwiftUI

/// The app's entry point. SwiftUI creates exactly one `SliceApp` and asks it for scenes.
/// Slice has no regular window — its only scene is the menu bar item.
@main
struct SliceApp: App {
    /// The one timer for the whole app. `@State` on an `@Observable` class keeps a
    /// single instance alive for the app's lifetime; views observe it directly.
    @State private var timer: PomodoroTimer

    init() {
        // Durations live in UserDefaults (the app's preferences file) so they survive
        // relaunch. Missing key → `object(forKey:)` is nil → default. Phase 5 adds the UI.
        let defaults = UserDefaults.standard
        let workMinutes = defaults.object(forKey: "workMinutes") as? Int ?? 25
        let breakMinutes = defaults.object(forKey: "breakMinutes") as? Int ?? 5
        let cycles = defaults.object(forKey: "cycles") as? Int ?? 0
        let timer = PomodoroTimer(
            workDuration: TimeInterval(workMinutes * 60),
            breakDuration: TimeInterval(breakMinutes * 60),
            cycles: cycles
        )
        // Wire the model's completion hook once, at launch. The alert style is
        // re-read every time so a change in Settings applies without a relaunch.
        // One or the other: the alarm window replaces the banner, not adds to it.
        timer.onPhaseCompleted = { finished, next in
            switch AlertStyle.load() {
            case .banner: Notifications.post(for: finished, next: next)
            case .alarm: Alarm.show(for: finished, next: next)
            }
        }
        // `_timer` is the `State` wrapper itself; this is how you seed `@State`
        // from an initializer.
        _timer = State(initialValue: timer)
    }

    var body: some Scene {
        // `MenuBarExtra` puts an item in the macOS menu bar (macOS 13+).
        // The `label` closure is what you see in the bar; the main closure is the
        // content that opens when you click it.
        MenuBarExtra {
            MenuBarView(timer: timer)
        } label: {
            // An `HStack` of image + text shows both in the menu bar.
            // (`Label` would show only the icon here.) Reading `timer.displayText`
            // here is enough: SwiftUI re-renders the label whenever it changes.
            HStack(spacing: 4) {
                // Our own icon from the asset catalog. It is marked "template" there,
                // so macOS recolors it to match the menu bar in light and dark mode.
                Image("MenuBarIcon")
                Text(timer.displayText)
                    .monospacedDigit()
            }
        }
        // `.window` shows a small panel (like a popover) instead of a drop-down
        // menu, so we can put real SwiftUI controls in it.
        .menuBarExtraStyle(.window)
    }
}
