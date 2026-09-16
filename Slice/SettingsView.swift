import SwiftUI
import ServiceManagement

/// Durations, cycles, launch-at-login and alert style. Shown inside the menu bar
/// panel when the gear button is on, so there is no separate settings window to manage.
struct SettingsView: View {
    let timer: PomodoroTimer

    /// `@AppStorage` is a property wrapper that reads and writes `UserDefaults`
    /// and re-renders the view when the value changes. Same keys that
    /// `SliceApp.init()` reads at launch.
    @AppStorage("workMinutes") private var workMinutes = 25
    @AppStorage("breakMinutes") private var breakMinutes = 5
    /// 0 means "off": one round per Start, as before.
    @AppStorage("cycles") private var cycles = 0
    /// Stored as the enum's raw string so `@AppStorage` can hold it.
    @AppStorage(AlertStyle.defaultsKey) private var alertStyle = AlertStyle.banner.rawValue

    /// What the cycles text field shows. Kept as a `String` (not bound straight
    /// to `cycles`) so anything that is not a digit can be dropped as it is typed.
    @State private var cyclesText = ""

    /// `SMAppService.mainApp` is macOS's launch-at-login registry for this app
    /// (macOS 13+). Its `status` is the source of truth; we mirror it in state.
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper("Work: \(workMinutes) min", value: $workMinutes, in: 1...120)
            Stepper("Break: \(breakMinutes) min", value: $breakMinutes, in: 1...60)
            // Typed or stepped, any count from 0 up: no upper limit on purpose.
            HStack(spacing: 4) {
                Text(cycles == 0 ? "Cycles: off" : "Cycles")
                TextField("0", text: $cyclesText)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 52)
                Stepper("", value: $cycles, in: 0...Int.max)
                    .labelsHidden()
            }
            Toggle("Launch at login", isOn: $launchAtLogin)
            // Banner = one notification. Alarm = a floating window + looping sound
            // until you click Dismiss, instead of the banner.
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
        // `onAppear` runs once the view is on screen; seed the field from the saved value.
        .onAppear { cyclesText = String(cycles) }
        // `onChange` runs after the wrapped value changes; the zero-argument form
        // (macOS 14+) is enough because we re-read the properties inside.
        .onChange(of: workMinutes) { applyDurations() }
        .onChange(of: breakMinutes) { applyDurations() }
        .onChange(of: cyclesText) { applyCyclesText() }
        .onChange(of: cycles) {
            // Stepper (or a cleaned-up typo) moved the number: mirror it into the field,
            // except while the field is empty and the value is already 0 — rewriting
            // "" to "0" there would fight the user mid-edit.
            if Int(cyclesText) != cycles && !(cyclesText.isEmpty && cycles == 0) {
                cyclesText = String(cycles)
            }
            applyDurations()
        }
        .onChange(of: launchAtLogin) { setLaunchAtLogin(launchAtLogin) }
    }

    /// Keeps only ASCII digits in the field and turns them into `cycles`.
    /// Empty means 0; a number too big for `Int` means "as many as possible".
    private func applyCyclesText() {
        let digits = cyclesText.filter { $0.isASCII && $0.isNumber }
        if digits != cyclesText {
            // Strip the bad characters; this re-triggers `onChange(of: cyclesText)`
            // with clean text, which then falls through to the else branch.
            cyclesText = digits
        } else {
            cycles = Int(digits) ?? (digits.isEmpty ? 0 : Int.max)
        }
    }

    /// Pushes the chosen values into the model. A new work length should show up
    /// in the menu bar right away, but never interrupt a session in progress —
    /// and never forget how many cycles are done, so this is not `reset()`.
    private func applyDurations() {
        timer.workDuration = TimeInterval(workMinutes * 60)
        timer.breakDuration = TimeInterval(breakMinutes * 60)
        timer.cycles = cycles
        timer.refreshIdleDuration()
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
