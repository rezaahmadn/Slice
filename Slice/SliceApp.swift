import SwiftUI

/// The app's entry point. SwiftUI creates exactly one `SliceApp` and asks it for scenes.
/// Slice has no regular window — its only scene is the menu bar item.
@main
struct SliceApp: App {
    /// The one timer for the whole app. `@State` on an `@Observable` class keeps a
    /// single instance alive for the app's lifetime; views observe it directly.
    @State private var timer = PomodoroTimer()

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
                Image(systemName: "timer")
                Text(timer.displayText)
                    .monospacedDigit()
            }
        }
        // `.window` shows a small panel (like a popover) instead of a drop-down
        // menu, so we can put real SwiftUI controls in it.
        .menuBarExtraStyle(.window)
    }
}
