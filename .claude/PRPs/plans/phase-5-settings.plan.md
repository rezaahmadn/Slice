# Plan: Phase 5 — Settings

## Summary
Add a gear button to the panel that unfolds a settings section: work minutes, break minutes (steppers, persisted via `@AppStorage`), and a "Launch at login" toggle backed by `SMAppService`. Duration changes apply immediately when the timer is idle and never interrupt a running session.

**Dry-run on this machine on 2026-09-15 on top of Phases 1–4: build clean, `✔ Test run with 13 tests in 3 suites passed`; clicking the work stepper's increment changed the menu bar to `26:00`, the row to `Work: 26 min`, and `defaults read com.rezaahmadn.Slice workMinutes` to `26`; toggling "Launch at login" registered `com.rezaahmadn.Slice` in Background Task Management (`Disposition: [enabled, allowed, notified]`) and toggling it off removed it.** Copy every file exactly.

## User Story
As Reza, I want to set my own work/break lengths and have Slice start at login, so that the timer matches how I actually work and is always there.

## Problem → Solution
Fixed 25/5 read from defaults with no UI, no autostart → gear button → inline `SettingsView` with two steppers and a toggle.

## Metadata
- **Complexity**: Small
- **Source PRD**: `.claude/PRPs/prds/slice.prd.md`
- **PRD Phase**: 5 — Settings
- **Estimated Files**: 1 created, 2 edited, 1 test added, README line, `project.pbxproj` regenerated

---

## UX Design

### Before
```
   ┌─────────────────────┐
   │        Work         │
   │       25:00         │
   │  [Start]  [Reset]   │
   │ ─────────────────── │
   │    [Quit Slice]     │
   └─────────────────────┘
```

### After (gear on)
```
   ┌───────────────────────┐
   │         Work          │
   │        25:00          │
   │ [Start] [Reset]  [⚙]  │
   │ ───────────────────── │
   │ Work: 25 min    [-][+]│
   │ Break: 5 min    [-][+]│
   │ Launch at login   (○) │
   │ ───────────────────── │
   │     [Quit Slice]      │
   └───────────────────────┘
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| Gear button | none | toggles settings section | `button 3` in accessibility |
| Work/Break steppers | none | 1–120 / 1–60 min, saved to `UserDefaults` | idle timer resets to new length immediately |
| Launch at login | none | `SMAppService.mainApp.register()/unregister()` | error shown as red caption if it fails |
| Quit | `button 3` | `button 4` | scripts must update |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `Slice/MenuBarView.swift` | all | Being replaced; keep everything else identical |
| P0 | `Slice/SliceApp.swift` | `init()` | Reads the same `workMinutes`/`breakMinutes` keys at launch |
| P0 | `Slice/PomodoroTimer.swift` | `workDuration`, `breakDuration`, `reset()` | What `applyDurations()` touches |
| P1 | `SliceTests/PomodoroTimerTests.swift` | all | One test appended at the end |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| AppStorage | https://developer.apple.com/documentation/swiftui/appstorage | `@AppStorage("key") var x = default` reads/writes `UserDefaults.standard` |
| SMAppService | https://developer.apple.com/documentation/servicemanagement/smappservice | `mainApp.register()`, `unregister()`, `status == .enabled`; macOS 13+ |
| onChange | https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:)-4dbn3 | zero-parameter closure form, macOS 14+ |

Verified facts (from the dry run — treat as law):

KEY_INSIGHT: `SMAppService.mainApp.register()` works for an ad-hoc signed app living in DerivedData; it registers that exact path. Toggle it OFF again in validation so no login item points at a build folder.
APPLIES_TO: Validation 4.

KEY_INSIGHT: `sfltool dumpbtm` sometimes hangs; do not use it in validation. The toggle's initial value is seeded from `SMAppService.mainApp.status` at view creation, so relaunching the app and reading `value of checkbox 1` is the reliable proof that macOS stored the registration (1) or removed it (0).
APPLIES_TO: Validation 4.

KEY_INSIGHT: In accessibility, the steppers are `incrementor 1` (work) and `incrementor 2` (break) of `group 1 of window 1`; `button 1 of incrementor N` increments, `button 2` decrements. The toggle is `checkbox 1`. Gear is `button 3`, Quit becomes `button 4`.
APPLIES_TO: Validation 4.

KEY_INSIGHT: `setLaunchAtLogin` must guard against `enabled == current status`, otherwise the rollback in `catch` re-triggers `onChange` and loops.
APPLIES_TO: `SettingsView.swift`.

---

## Patterns to Mirror

### VIEW_STRUCTURE
// SOURCE: `Slice/MenuBarView.swift` — `struct XView: View`, `let timer: PomodoroTimer`, `#Preview` at the bottom.

### COMMENT_STYLE
// SOURCE: `Slice/Notifications.swift:5-7` — `///` on the type explaining the idiom, `//` inside explaining why.

### ERROR_HANDLING
// SOURCE: Phase 1 plan rule — user-facing failures shown as a short `Text` in the panel, never an alert. `launchError` follows it.

### TEST_STRUCTURE
// SOURCE: `SliceTests/PomodoroTimerTests.swift` — `@MainActor struct`, `@Test func`, `#expect`.

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `Slice/SettingsView.swift` | CREATE | Steppers + toggle |
| `Slice/MenuBarView.swift` | REPLACE | Gear button, settings section, width 240 |
| `SliceTests/PomodoroTimerTests.swift` | EDIT | Append one test |
| `Slice.xcodeproj/project.pbxproj` | REGENERATE | New file |
| `README.md` | UPDATE | Status line |

## NOT Building
- A separate Settings window / `Settings` scene / Cmd+,
- Long-break cycle, sound picker, hotkey
- Changing `SliceApp.swift` (it already reads the keys at launch)
- Changing `PomodoroTimer.swift`

---

## Step-by-Step Tasks

All commands run from `/Users/reza/Slice`. Use absolute paths.

### Task 1: Create `Slice/SettingsView.swift`
- **ACTION**: Create with EXACTLY this content.
- **IMPLEMENT**:
```swift
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

    /// `SMAppService.mainApp` is macOS's launch-at-login registry for this app
    /// (macOS 13+). Its `status` is the source of truth; we mirror it in state.
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper("Work: \(workMinutes) min", value: $workMinutes, in: 1...120)
            Stepper("Break: \(breakMinutes) min", value: $breakMinutes, in: 1...60)
            Toggle("Launch at login", isOn: $launchAtLogin)
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
```
- **IMPORTS**: `SwiftUI`, `ServiceManagement`
- **GOTCHA**: Keep the `guard` in `setLaunchAtLogin`. Keep `let timer`, not `@State`.
- **VALIDATE**: Validation 1 build.

### Task 2: Replace `Slice/MenuBarView.swift`
- **ACTION**: Overwrite with EXACTLY this content.
- **IMPLEMENT**:
```swift
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
            Text(timer.phase.title)
                .font(.headline)
                .foregroundStyle(.secondary)

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
```
- **GOTCHA**: The gear button is the third button inside the `HStack`, before the `Divider`. Frame width is now 240. The Phase 4 `Task { await Notifications.requestAuthorization() }` lines must remain.
- **VALIDATE**: Validation 1 build; Validation 4 probe.

### Task 3: Append a test to `SliceTests/PomodoroTimerTests.swift`
- **ACTION**: Insert the following EXACTLY before the file's final closing `}` (the one that closes `struct PomodoroTimerTests`), keeping one blank line before it:
```swift
    @Test func newWorkDurationShowsAfterResetWhileIdle() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4)
        timer.workDuration = 20   // what SettingsView does when the stepper moves
        timer.reset()
        #expect(timer.remaining == 20)
        #expect(timer.displayText == "00:20")
    }
```
- **VALIDATE**: `tail -12 SliceTests/PomodoroTimerTests.swift` shows the new test followed by a single `}` on the last line; Validation 2 shows 13 tests.

### Task 4: README status line
- **ACTION**: Replace the `**Status:**` line with EXACTLY:
```
**Status:** work in progress — Phase 5 of 7 (settings). Work/break lengths and launch at login are configurable from the gear in the panel. A downloadable release is next.
```
- **NOTE**: If Phase 6 (icon) already landed (README has an `## Icons` section), use instead: `**Status:** work in progress — Phase 5 of 7 (settings). Timer, notifications, icon and settings are done; a downloadable release is next.`
- **VALIDATE**: `grep -c "Phase 5 of 7" README.md` prints `1`.

### Task 5: Regenerate, validate, commit, push
- **ACTION**: `xcodegen generate`, Validation Commands 1–4, then:
```sh
git add -A
git commit -m "feat: settings — work/break minutes and launch at login

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
```
- **VALIDATE**: `git status --short` empty; `git log --oneline -1` shows the commit.

---

## Testing Strategy

### Unit Tests
| Test | Input | Expected Output | Edge Case? |
|---|---|---|---|
| newWorkDurationShowsAfterResetWhileIdle | set `workDuration = 20`, `reset()` | remaining 20, "00:20" | duration change path |

### Edge Cases Checklist
- [x] Stepper bounds 1…120 / 1…60 enforced by `Stepper(in:)`
- [x] Change while running — model durations update, countdown untouched until next reset/phase
- [x] Launch-at-login failure — red caption, toggle rolled back, no loop
- [ ] App moved after registering — macOS tracks the bundle by path; re-toggle if moved

---

## Validation Commands

Run from `/Users/reza/Slice`, in order.

### 1. Generate + build
```sh
xcodegen generate | tail -1
grep -c "SettingsView" Slice.xcodeproj/project.pbxproj
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug build 2>&1 | grep -E "error:|warning:|BUILD" | grep -v -E "appintentsmetadataprocessor|Error Domain"
```
EXPECT: `Created project at /Users/reza/Slice/Slice.xcodeproj`, a number ≥ 2, then exactly `** BUILD SUCCEEDED **`.

### 2. Test
```sh
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug test 2>&1 | grep -E "✘|Test run with|TEST (SUCCEEDED|FAILED)" | grep -v "Error Domain"
```
EXPECT: `✔ Test run with 13 tests in 3 suites passed` and `** TEST SUCCEEDED **`.

### 3. Only the planned files changed
```sh
git status --short
```
EXPECT: `M README.md`, `M Slice.xcodeproj/project.pbxproj`, `M Slice/MenuBarView.swift`, `M SliceTests/PomodoroTimerTests.swift`, `?? Slice/SettingsView.swift`. Nothing else.

### 4. Live probe: stepper, defaults, launch at login (three launches, then cleanup)
```sh
APP="$(xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR =/{print $3}')/Slice.app"
cat > /tmp/slice-ensure.applescript <<'APPLESCRIPT'
on ensurePanel()
  tell application "System Events"
    tell process "Slice"
      if (count windows) = 0 then
        click menu bar item 1 of menu bar 2
        delay 1
      end if
    end tell
  end tell
end ensurePanel
APPLESCRIPT
pkill -x Slice; sleep 1
defaults delete com.rezaahmadn.Slice workMinutes 2>/dev/null; defaults delete com.rezaahmadn.Slice breakMinutes 2>/dev/null
open "$APP"; sleep 4
echo "--- A: increment + register ---"
osascript <<'APPLESCRIPT'
on ensurePanel()
  tell application "System Events"
    tell process "Slice"
      if (count windows) = 0 then
        click menu bar item 1 of menu bar 2
        delay 1
      end if
    end tell
  end tell
end ensurePanel

tell application "System Events"
  tell process "Slice"
    my ensurePanel()
    click button 3 of group 1 of window 1
    delay 1
    click button 1 of incrementor 1 of group 1 of window 1
    delay 1
    set afterInc to {name of menu bar item 1 of menu bar 2, name of static text 3 of group 1 of window 1}
    my ensurePanel()
    click checkbox 1 of group 1 of window 1
    delay 2
    set cbOn to value of checkbox 1 of group 1 of window 1
    set texts to name of every static text of group 1 of window 1
    return {afterInc, cbOn, texts}
  end tell
end tell
APPLESCRIPT
echo "workMinutes=$(defaults read com.rezaahmadn.Slice workMinutes)"
pkill -x Slice; sleep 1; open "$APP"; sleep 4
echo "--- B: registration persisted, then unregister + decrement ---"
osascript <<'APPLESCRIPT'
on ensurePanel()
  tell application "System Events"
    tell process "Slice"
      if (count windows) = 0 then
        click menu bar item 1 of menu bar 2
        delay 1
      end if
    end tell
  end tell
end ensurePanel

tell application "System Events"
  tell process "Slice"
    my ensurePanel()
    click button 3 of group 1 of window 1
    delay 1
    set persisted to value of checkbox 1 of group 1 of window 1
    click checkbox 1 of group 1 of window 1
    delay 2
    set cbOff to value of checkbox 1 of group 1 of window 1
    my ensurePanel()
    click button 2 of incrementor 1 of group 1 of window 1
    delay 1
    return {persisted, cbOff, name of menu bar item 1 of menu bar 2}
  end tell
end tell
APPLESCRIPT
pkill -x Slice; sleep 1; open "$APP"; sleep 4
echo "--- C: unregistration persisted ---"
osascript <<'APPLESCRIPT'
on ensurePanel()
  tell application "System Events"
    tell process "Slice"
      if (count windows) = 0 then
        click menu bar item 1 of menu bar 2
        delay 1
      end if
    end tell
  end tell
end ensurePanel

tell application "System Events"
  tell process "Slice"
    my ensurePanel()
    click button 3 of group 1 of window 1
    delay 1
    return value of checkbox 1 of group 1 of window 1
  end tell
end tell
APPLESCRIPT
pkill -x Slice
defaults delete com.rezaahmadn.Slice workMinutes 2>/dev/null; defaults delete com.rezaahmadn.Slice breakMinutes 2>/dev/null
echo "defaults-left=$(defaults read com.rezaahmadn.Slice 2>&1 | grep -c Minutes)"
```
EXPECT, in order: A → `26:00, Work: 26 min, 1, Work, 26:00, Work: 26 min, Break: 5 min` (no error caption among the texts); `workMinutes=26`; B → `1, 0, 25:00` (the leading `1` proves macOS kept the registration across a relaunch); C → `0`; `defaults-left=0`. If any osascript errors with "Can't get window 1", re-run Validation 4 once from the top.

### 5. After commit and push
```sh
git status --short; git log --oneline -1
```
EXPECT: empty status; commit line containing `feat: settings`.

---

## Acceptance Criteria
- [ ] Tasks 1–5 done
- [ ] Validations 1–5 match EXPECT
- [ ] Validation 4 step C printed `0` (no stray login item pointing at the build folder)
- [ ] Pushed

## Completion Checklist
- [ ] Files byte-identical to plan
- [ ] `SliceApp.swift`, `PomodoroTimer.swift`, `Notifications.swift` untouched
- [ ] No `print`, `try!`, `fatalError`
- [ ] PRD Phase 5 row → `complete` (orchestrator)

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Panel focus flake | L | osascript "Can't get window 1" | one re-run allowed |
| Login item left registered pointing at DerivedData | L | App auto-launches from build folder | Validation 4 toggles it off and step C asserts `0` |

## Notes
- Launch at login for the *real* app should be toggled from wherever the user finally keeps `Slice.app` (e.g. `/Applications`); macOS stores the path.
- Phase 6 changed only the label image in `SliceApp.swift`; this phase does not touch that file, so order 5↔6 does not matter.
