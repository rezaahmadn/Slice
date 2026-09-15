import SwiftUI

/// The app's entry point. SwiftUI creates exactly one `SliceApp` and asks it for scenes.
/// Slice has no regular window — its only scene is the menu bar item.
@main
struct SliceApp: App {
    var body: some Scene {
        // `MenuBarExtra` puts an item in the macOS menu bar (macOS 13+).
        // The `label` closure is what you see in the bar; the main closure is the
        // content that opens when you click it. "25:00" is hardcoded for now —
        // Phase 2 binds it to the timer.
        MenuBarExtra {
            MenuBarView()
        } label: {
            // An `HStack` of image + text shows both in the menu bar.
            // (`Label` would show only the icon here.)
            HStack(spacing: 4) {
                Image(systemName: "timer")
                Text("25:00")
            }
        }
        // `.window` shows a small panel (like a popover) instead of a drop-down
        // menu, so we can put real SwiftUI controls in it later.
        .menuBarExtraStyle(.window)
    }
}
