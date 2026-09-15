# Plan: Phase 3 — Menu Bar UI

## Summary
Bind the menu bar label to the live `PomodoroTimer` and replace the placeholder panel with real controls: phase name, big countdown, Start/Pause toggle, Reset, Quit. After this phase Slice is a working Pomodoro timer (no notifications yet).

**Both files below were dry-run on this machine on 2026-09-15 on top of Phases 1–2: build succeeded with zero warnings, 10 tests passed, and the Validation 4 script (as now written) returned `25:00, Work, 25:00, 24:58, 25:00`.** Copy them exactly.

## User Story
As Reza, I want to start, pause and reset the timer from the menu bar and see the countdown there, so that I can commit to a work window without opening any window.

## Problem → Solution
Static `25:00` label and placeholder panel → label shows `timer.displayText` live; panel shows phase, countdown, Start/Pause, Reset (disabled when idle), Quit.

## Metadata
- **Complexity**: Small
- **Source PRD**: `.claude/PRPs/prds/slice.prd.md`
- **PRD Phase**: 3 — Menu bar UI
- **Estimated Files**: 2 modified, 1 README line

---

## UX Design

### Before
```
Menu bar: ⏱ 25:00 (static)
Panel:    Slice / Timer coming soon. / [Quit Slice]
```

### After
```
Menu bar: ⏱ 24:58  ← ticks every second while running
Panel:
   ┌─────────────────────┐
   │        Work         │  ← phase title, secondary color
   │       24:58         │  ← 44pt rounded light, monospaced digits
   │  [Pause]  [Reset]   │  ← Start↔Pause toggles; Reset disabled when idle
   │ ─────────────────── │
   │    [Quit Slice]     │
   └─────────────────────┘
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| Menu bar label | static | live `displayText` | `.monospacedDigit()` avoids jitter |
| Start/Pause | none | one button, title follows `state` | Enter key triggers it (`.defaultAction`) |
| Reset | none | returns to idle 25:00 | disabled while idle |
| Quit | exists | unchanged | Cmd+Q |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `Slice/PomodoroTimer.swift` | all | Public surface: `phase.title`, `state`, `displayText`, `start()`, `pause()`, `reset()` |
| P0 | `Slice/SliceApp.swift` | all | File being replaced; keep its comment style |
| P0 | `Slice/MenuBarView.swift` | all | File being replaced |
| P1 | `.claude/PRPs/plans/phase-1-project-skeleton.plan.md` | "Verified facts" | Notch gotcha, `Label` gotcha |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| State + Observable | https://developer.apple.com/documentation/swiftui/state | `@State private var model = Model()` owns one instance of an `@Observable` class for the scene's lifetime |
| Observation in views | https://developer.apple.com/documentation/observation | A view holding an `@Observable` object as a plain `let` still re-renders when read properties change |
| keyboardShortcut | https://developer.apple.com/documentation/swiftui/view/keyboardshortcut(_:) | `.defaultAction` = Return key |

Verified facts (from the dry run — treat as law):

KEY_INSIGHT: `MenuBarExtra`'s `label:` closure re-renders when `timer.displayText` changes. No `@Bindable`, no `@Environment`, no timer publisher in the view needed.
APPLIES_TO: `SliceApp.swift`.

KEY_INSIGHT: In the accessibility tree the panel is `window 1 of process "Slice"` and its controls are `button 1/2/3 of group 1 of window 1` (Start-or-Pause, Reset, Quit). Button *names* read as `missing value`; use indexes. Clicking the menu bar item toggles the panel, so a script must check `count windows` and click again if it closed.
APPLIES_TO: Validation 4.

KEY_INSIGHT: The panel closes when it loses focus (e.g. running `screencapture` from a separate command). Do all UI probing inside ONE `osascript` invocation.
APPLIES_TO: Validation 4.

---

## Patterns to Mirror

### COMMENT_STYLE
// SOURCE: `Slice/PomodoroTimer.swift:3-9`
```swift
/// The Pomodoro state machine. Owns every piece of timer state; views only read it
/// and call `start()`, `pause()`, `reset()`.
///
/// `@MainActor` keeps all reads and writes on the main thread — what SwiftUI needs,
```

### VIEW_STRUCTURE
// SOURCE: `Slice/MenuBarView.swift` (Phase 1 version)
`struct XView: View`, `var body: some View`, `VStack(spacing: 12)`, `.padding(16)`, fixed `.frame(width:)`, `#Preview` at bottom.

### MODEL_ACCESS
// SOURCE: `Slice/PomodoroTimer.swift` — `private(set) var phase/state/remaining`, methods `start(now:)`, `pause(now:)`, `reset()`, computed `displayText`.
Views never mutate properties directly; they call the three methods.

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `Slice/SliceApp.swift` | REPLACE | Own the timer, bind label |
| `Slice/MenuBarView.swift` | REPLACE | Real controls |
| `README.md` | UPDATE | Status line only |

## NOT Building
- Settings / gear button (Phase 5)
- Notifications (Phase 4)
- Custom icon (Phase 6) — SF Symbol `timer` stays
- Any change to `PomodoroTimer.swift`, tests, or `project.yml` (no new files, so no `xcodegen generate` needed)

---

## Step-by-Step Tasks

All commands run from `/Users/reza/Slice`. Use absolute paths.

### Task 1: Replace `Slice/SliceApp.swift`
- **ACTION**: Overwrite the file with EXACTLY this content.
- **IMPLEMENT**:
```swift
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
```
- **MIRROR**: COMMENT_STYLE
- **GOTCHA**: `@State private var timer = PomodoroTimer()` — `private` and `@State`, not `let`, otherwise SwiftUI may recreate the model. Keep `HStack`, not `Label`.
- **VALIDATE**: Validation 2 build.

### Task 2: Replace `Slice/MenuBarView.swift`
- **ACTION**: Overwrite the file with EXACTLY this content.
- **IMPLEMENT**:
```swift
import SwiftUI

/// Content of the panel that opens when you click the menu bar item:
/// current phase, big countdown, and the three controls.
struct MenuBarView: View {
    /// A plain `let` is enough for an `@Observable` class: SwiftUI tracks which
    /// properties `body` reads and re-renders when they change.
    let timer: PomodoroTimer

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
                    }
                }
                .keyboardShortcut(.defaultAction)

                Button("Reset") {
                    timer.reset()
                }
                .disabled(timer.state == .idle)
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
        .frame(width: 220)
    }
}

#Preview {
    MenuBarView(timer: PomodoroTimer())
}
```
- **MIRROR**: VIEW_STRUCTURE, MODEL_ACCESS
- **GOTCHA**: `let timer: PomodoroTimer`, not `@State`/`@Bindable`. `#Preview` must pass `PomodoroTimer()`.
- **VALIDATE**: Validation 2 build; Validation 4 UI probe.

### Task 3: Update README status line
- **ACTION**: In `README.md`, replace the line starting with `**Status:**` with EXACTLY:
```
**Status:** work in progress — Phase 3 of 7 (menu bar UI). The timer works: Start, Pause, Reset from the menu bar. Notifications are next.
```
- **VALIDATE**: `grep -c "Phase 3 of 7" README.md` prints `1`.

### Task 4: Validate, commit, push
- **ACTION**: Run Validation Commands 1–5, then:
```sh
git add -A
git commit -m "feat: live countdown in menu bar with Start/Pause/Reset panel

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
```
- **VALIDATE**: `git status --short` empty; `git log --oneline -1` shows the commit.

---

## Testing Strategy

### Unit Tests
No new unit tests — views have no logic beyond calling model methods. Existing 10 tests must still pass.

### Edge Cases Checklist
- [x] Reset while idle — button disabled
- [x] Start while running — button reads Pause, calls `pause()`
- [x] Label update while panel closed — verified via accessibility read of menu bar item

---

## Validation Commands

Run from `/Users/reza/Slice`, in order.

### 1. Only two Swift files changed
```sh
git status --short
```
EXPECT: exactly `M README.md`, `M Slice/MenuBarView.swift`, `M Slice/SliceApp.swift`. Nothing else.

### 2. Build
```sh
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug build 2>&1 | grep -E "error:|warning:|BUILD" | grep -v appintentsmetadataprocessor
```
EXPECT: exactly one line: `** BUILD SUCCEEDED **`.

### 3. Test
```sh
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug test 2>&1 | grep -E "✘|Test run with|TEST (SUCCEEDED|FAILED)" | grep -v "Error Domain"
```
EXPECT: `✔ Test run with 10 tests in 2 suites passed` and `** TEST SUCCEEDED **`.

### 4. Live UI probe (single osascript, do not split it)
```sh
APP="$(xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR =/{print $3}')/Slice.app"
pkill -x Slice; sleep 1; open "$APP"; sleep 4
osascript <<'APPLESCRIPT'
tell application "System Events"
  tell process "Slice"
    set beforeLabel to name of menu bar item 1 of menu bar 2
    click menu bar item 1 of menu bar 2
    delay 1
    if (count windows) = 0 then
      click menu bar item 1 of menu bar 2
      delay 1
    end if
    set texts to name of every static text of group 1 of window 1
    click button 1 of group 1 of window 1
    delay 2.5
    set runningLabel to name of menu bar item 1 of menu bar 2
    click button 2 of group 1 of window 1
    delay 0.5
    set afterReset to name of menu bar item 1 of menu bar 2
    return {beforeLabel, texts, runningLabel, afterReset}
  end tell
end tell
APPLESCRIPT
pkill -x Slice
```
EXPECT: `25:00, Work, 25:00, 24:58, 25:00` (the third value may be `24:57` or `24:58` depending on timing; anything between `24:56` and `24:58` passes). The first `25:00` is the idle label, `Work, 25:00` are the panel texts, `24:5x` proves the label ticks, final `25:00` proves Reset.

### 5. Screenshot (optional visual check)
```sh
open "$APP"; sleep 3
osascript -e 'tell application "System Events" to tell process "Slice" to click menu bar item 1 of menu bar 2'; sleep 1
screencapture -x -R 400,0,700,260 /tmp/slice-phase3.png; pkill -x Slice
```
EXPECT: Read `/tmp/slice-phase3.png` — panel shows "Work", large "25:00", a highlighted Start button, a greyed Reset button, and Quit Slice. (The panel may close before capture if focus moves; if the image shows no panel, Validation 4 is still the authoritative pass.)

### 6. After commit and push
```sh
git status --short; git log --oneline -1
```
EXPECT: empty status; commit line containing `feat: live countdown`.

---

## Acceptance Criteria
- [ ] Tasks 1–4 done
- [ ] Validations 1–4 and 6 match EXPECT
- [ ] Pushed to `origin/main`

## Completion Checklist
- [ ] Files match the plan byte-for-byte
- [ ] `PomodoroTimer.swift`, tests, `project.yml`, `project.pbxproj` untouched
- [ ] No `print`, `try!`, `fatalError`
- [ ] PRD Phase 3 row → `complete` (orchestrator)

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Panel toggles closed during probe | M | Validation 4 error "Can't get window 1" | Script already re-clicks; if it still fails, re-run Validation 4 once |
| Menu bar item under notch | Certain on this Mac | Cosmetic | Accessibility read is the proof |

## Notes
- Button accessibility names are `missing value` for SwiftUI buttons in this panel; indexes 1/2/3 = Start-or-Pause / Reset / Quit are stable because the view order is fixed.
- Phase 5 will add a gear button as `button 3` and push Quit to `button 4`; update scripts then.
