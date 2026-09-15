import SwiftUI

/// Content of the panel that opens when you click the menu bar item.
/// Phase 3 replaces the placeholder with the real timer controls.
struct MenuBarView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Slice")
                .font(.headline)
            Text("Timer coming soon.")
                .foregroundStyle(.secondary)
            Divider()
            // Menu-bar-only apps have no Dock icon or app menu, so users need an
            // explicit way to quit. `NSApplication` is AppKit's app object; SwiftUI
            // re-exports AppKit on macOS so no extra import is needed.
            Button("Quit Slice") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 200)
    }
}

#Preview {
    MenuBarView()
}
