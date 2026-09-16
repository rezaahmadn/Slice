import SwiftUI

/// Content of the panel that opens when you click the menu bar item:
/// current phase, big countdown, the controls, and (behind the gear) settings.
struct MenuBarView: View {
    /// A plain `let` is enough for an `@Observable` class: SwiftUI tracks which
    /// properties `body` reads and re-renders when they change.
    let timer: PomodoroTimer

    /// `@State` is view-local storage that survives re-renders. Whether the
    /// settings section is unfolded.
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(timer.phase.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                // Only shown while cycles are on (`cycleLabel` is nil otherwise).
                if let cycleLabel = timer.cycleLabel {
                    Text(cycleLabel)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(timer.displayText)
                .font(.system(size: 44, weight: .light, design: .rounded))
                // Every digit takes the same width, so the text doesn't jitter each second.
                .monospacedDigit()

            HStack(spacing: 8) {
                // One button toggles between Start and Pause depending on state.
                Button(timer.state == .running ? "Pause" : "Start") {
                    if timer.state == .running {
                        timer.pause()
                    } else {
                        timer.start()
                        // First press asks macOS for notification permission;
                        // later presses return instantly with the saved answer.
                        Task { await Notifications.requestAuthorization() }
                    }
                }
                .keyboardShortcut(.defaultAction)

                Button("Reset") {
                    timer.reset()
                }
                .disabled(timer.state == .idle)

                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }

            if showSettings {
                Divider()
                SettingsView(timer: timer)
            }

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
        .frame(width: 240)
    }
}

#Preview {
    MenuBarView(timer: PomodoroTimer())
}
