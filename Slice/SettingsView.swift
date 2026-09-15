import SwiftUI
import ServiceManagement

/// Durations and launch-at-login. Shown inside the menu bar panel when the gear
/// button is on, so there is no separate settings window to manage.
struct SettingsView: View {
    let timer: PomodoroTimer

    /// `@AppStorage` is a property wrapper that reads and writes `UserDefaults`
    /// and re-renders the view when the value changes. Same keys that
    /// `SliceApp.init()` reads at launch.
    @AppStorage("workMinutes") private var workMinutes = 25
    @AppStorage("breakMinutes") private var breakMinutes = 5
    /// Stored as the enum's raw string so `@AppStorage` can hold it.
    @AppStorage(AlertStyle.defaultsKey) private var alertStyle = AlertStyle.banner.rawValue

    /// `SMAppService.mainApp` is macOS's launch-at-login registry for this app
    /// (macOS 13+). Its `status` is the source of truth; we mirror it in state.
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper("Work: \(workMinutes) min", value: $workMinutes, in: 1...120)
            Stepper("Break: \(breakMinutes) min", value: $breakMinutes, in: 1...60)
            Toggle("Launch at login", isOn: $launchAtLogin)
            // Banner = one notification. Alarm = banner + floating window + looping
            // sound until you click Dismiss.
            Picker("Alert", selection: $alertStyle) {
                Text("Banner").tag(AlertStyle.banner.rawValue)
                Text("Alarm").tag(AlertStyle.alarm.rawValue)
            }
            .pickerStyle(.segmented)
            if let launchError {
                Text(launchError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        // `onChange` runs after the wrapped value changes; the zero-argument form
        // (macOS 14+) is enough because we re-read the properties inside.
        .onChange(of: workMinutes) { applyDurations() }
        .onChange(of: breakMinutes) { applyDurations() }
        .onChange(of: launchAtLogin) { setLaunchAtLogin(launchAtLogin) }
    }

    /// Pushes the chosen minutes into the model. A new work length should show up
    /// in the menu bar right away, but never interrupt a session in progress.
    private func applyDurations() {
        timer.workDuration = TimeInterval(workMinutes * 60)
        timer.breakDuration = TimeInterval(breakMinutes * 60)
        if timer.state == .idle {
            timer.reset()
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        // Skip when the toggle already matches the system (e.g. after a failed
        // attempt below rolled it back), otherwise we would loop.
        guard enabled != (SMAppService.mainApp.status == .enabled) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            launchError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

#Preview {
    SettingsView(timer: PomodoroTimer())
        .padding()
}
