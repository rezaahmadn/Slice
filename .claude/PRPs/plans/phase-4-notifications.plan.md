# Plan: Phase 4 — Notifications

## Summary
Post a macOS notification (banner + default sound) each time a Pomodoro phase ends, ask for permission the first time Start is pressed, and log both through `os.Logger`. Also pull one small piece forward from Phase 5: work/break durations are read from `UserDefaults` at launch (keys `workMinutes`, `breakMinutes`), which is what makes a 60-second end-to-end validation possible now and is exactly what the Settings UI will write later.

**Dry-run on this machine on 2026-09-15 on top of Phases 1–3: build clean, `✔ Test run with 12 tests in 3 suites passed`, and with `workMinutes = 1` the unified log showed `Notification permission granted: true` and, 60 s later, `Posted notification: Work done`. Notification permission for `com.rezaahmadn.Slice` is already granted on this Mac and survived a rebuild.** Copy every file exactly.

## User Story
As Reza, I want a banner and a sound when work ends and when the break ends, so that I never miss a transition while the menu bar is out of sight.

## Problem → Solution
Phase changes are silent → `Notifications.post(for:)` wired into `PomodoroTimer.onPhaseCompleted` at launch; `Notifications.requestAuthorization()` on first Start; durations from `UserDefaults`.

## Metadata
- **Complexity**: Small
- **Source PRD**: `.claude/PRPs/prds/slice.prd.md`
- **PRD Phase**: 4 — Notifications
- **Estimated Files**: 2 created, 2 edited, README line, `project.pbxproj` regenerated

---

## UX Design

### Before
```
Work ends → label flips to Break silently.
```

### After
```
First Start → macOS shows "“Slice” Notifications" permission banner (top-right), once.
Work ends  → banner "Work done — Take a break." + default sound; break starts.
Break ends → banner "Break over — Back to work when you're ready." + sound; idle 25:00.
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| First Start press | starts timer | starts timer + permission request | Request happens after `start()`, never blocks the timer |
| Phase end | silent | banner + sound | `UNNotificationSound.default` |
| Launch | fixed 25/5 | reads `workMinutes`/`breakMinutes` from defaults | Missing keys → 25/5 |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `Slice/PomodoroTimer.swift` | `onPhaseCompleted`, `init(workDuration:breakDuration:)` | The two hooks this phase uses |
| P0 | `Slice/SliceApp.swift` | all | Being replaced |
| P0 | `Slice/MenuBarView.swift` | Start/Pause button action | Three lines added there |
| P1 | `SliceTests/PomodoroTimerTests.swift` | first 10 lines | Test file header style |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| UNUserNotificationCenter | https://developer.apple.com/documentation/usernotifications/ununsernotificationcenter | `requestAuthorization(options:)` async throws; `add(_:withCompletionHandler:)` |
| os.Logger | https://developer.apple.com/documentation/os/logger | `Logger(subsystem:category:)`; `.notice` and `.error` are persisted, `.info` is not |
| Reading the log | `man log` | `/usr/bin/log show --predicate 'subsystem == "com.rezaahmadn.Slice"'` |

Verified facts (from the dry run — treat as law):

KEY_INSIGHT: `logger.info(...)` lines are NOT written to disk; `log show` never finds them. Use `.notice` for the two success lines and `.error` for failures.
APPLIES_TO: `Notifications.swift`.

KEY_INSIGHT: In zsh, `log` is a shell builtin. Always call `/usr/bin/log`.
APPLIES_TO: Validation 4.

KEY_INSIGHT: `xcodebuild test` output contains OS noise matching `error: Error Domain=...`; filter with `grep -v "Error Domain"`.
APPLIES_TO: Validation 2.

KEY_INSIGHT: On macOS 26 the permission request appears as a top-right *banner*, not a modal. It is already granted for `com.rezaahmadn.Slice` on this Mac, and the grant survived a rebuild with a different ad-hoc code hash, so validation runs unattended. If the log ever shows `Notification permission request failed: Notifications are not allowed for this application`, stop and report — the orchestrator will re-grant in System Settings.
APPLIES_TO: Validation 4.

KEY_INSIGHT: `UserDefaults.standard.object(forKey:) as? Int ?? 25` treats a missing key as the default; `integer(forKey:)` would return 0 and break the timer.
APPLIES_TO: `SliceApp.init()`.

KEY_INSIGHT: `defaults write com.rezaahmadn.Slice workMinutes -int 1` makes the next launch use a 1-minute work phase. Always `defaults delete` both keys afterwards or the real app will run 1-minute sessions.
APPLIES_TO: Validation 4.

---

## Patterns to Mirror

### COMMENT_STYLE
// SOURCE: `Slice/PomodoroTimer.swift:3-9` — `///` on types, `//` for why + concept intro.

### NAMESPACE_ENUM (new)
```swift
/// A case-less `enum` is Swift's idiom for a namespace: nothing to instantiate,
/// no state to hold.
enum Notifications { static func ... }
```

### LOGGING_PATTERN (new, established here)
```swift
private static let logger = Logger(subsystem: "com.rezaahmadn.Slice", category: "Notifications")
logger.notice("... \(value, privacy: .public)")   // success, persisted
logger.error("... \(error.localizedDescription, privacy: .public)")
```
Category = type name. Always `privacy: .public` on interpolations so `log show` prints them.

### TEST_STRUCTURE
// SOURCE: `SliceTests/PomodoroTimerTests.swift:1-11`

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `Slice/Notifications.swift` | CREATE | Permission + posting + content mapping |
| `SliceTests/NotificationsTests.swift` | CREATE | Tests the pure `content(for:)` mapping |
| `Slice/SliceApp.swift` | REPLACE | `init()` reads defaults, wires `onPhaseCompleted` |
| `Slice/MenuBarView.swift` | EDIT | 3 lines in the Start branch |
| `Slice.xcodeproj/project.pbxproj` | REGENERATE | Two new files |
| `README.md` | UPDATE | Status line |

## NOT Building
- Settings UI (Phase 5) — only the defaults *read* is here
- Custom sounds, notification actions/buttons, badge
- Full-screen break overlay
- Any change to `PomodoroTimer.swift`

---

## Step-by-Step Tasks

All commands run from `/Users/reza/Slice`. Use absolute paths.

### Task 1: Create `Slice/Notifications.swift`
- **ACTION**: Create with EXACTLY this content.
- **IMPLEMENT**:
```swift
import Foundation
import UserNotifications
import os

/// Posts a system notification (banner + sound) when a Pomodoro phase ends.
/// A case-less `enum` is Swift's idiom for a namespace: nothing to instantiate,
/// no state to hold.
enum Notifications {
    /// `os.Logger` writes to the unified system log. Read it with
    /// `log show --predicate 'subsystem == "com.rezaahmadn.Slice"'`.
    private static let logger = Logger(subsystem: "com.rezaahmadn.Slice", category: "Notifications")

    /// Asks macOS for permission. The system shows its prompt only the first time;
    /// later calls return the remembered answer immediately.
    /// Called when the user first presses Start, so the prompt has context.
    static func requestAuthorization() async {
        do {
            // `.alert` = banner, `.sound` = the ding. No `.badge`: there is no Dock icon.
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            // `.notice` (not `.info`) so the line is persisted and `log show` can find it.
            logger.notice("Notification permission granted: \(granted, privacy: .public)")
        } catch {
            logger.error("Notification permission request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Title and body for the phase that just ended. Pure, so it is unit-tested.
    static func content(for finished: PomodoroTimer.Phase) -> (title: String, body: String) {
        switch finished {
        case .work: ("Work done", "Take a break.")
        case .shortBreak: ("Break over", "Back to work when you're ready.")
        }
    }

    /// Delivers the notification now.
    static func post(for finished: PomodoroTimer.Phase) {
        let (title, body) = content(for: finished)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // `trigger: nil` means "deliver immediately". A fresh UUID per request so
        // two notifications never replace each other.
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("Failed to post notification: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.notice("Posted notification: \(title, privacy: .public)")
            }
        }
    }
}
```
- **MIRROR**: NAMESPACE_ENUM, LOGGING_PATTERN
- **IMPORTS**: `Foundation`, `UserNotifications`, `os`
- **GOTCHA**: `.notice`, not `.info`. `privacy: .public` on every interpolation.
- **VALIDATE**: Validation 1 build.

### Task 2: Create `SliceTests/NotificationsTests.swift`
- **ACTION**: Create with EXACTLY this content.
- **IMPLEMENT**:
```swift
import Testing
@testable import Slice

/// Only the pure text mapping is unit-tested; actual delivery is checked by hand.
struct NotificationsTests {
    @Test func workEndingSaysTakeABreak() {
        let c = Notifications.content(for: .work)
        #expect(c.title == "Work done")
        #expect(c.body == "Take a break.")
    }

    @Test func breakEndingSaysBackToWork() {
        let c = Notifications.content(for: .shortBreak)
        #expect(c.title == "Break over")
        #expect(c.body == "Back to work when you're ready.")
    }
}
```
- **VALIDATE**: Validation 2 shows 12 tests in 3 suites.

### Task 3: Replace `Slice/SliceApp.swift`
- **ACTION**: Overwrite with EXACTLY this content.
- **IMPLEMENT**:
```swift
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
        let timer = PomodoroTimer(
            workDuration: TimeInterval(workMinutes * 60),
            breakDuration: TimeInterval(breakMinutes * 60)
        )
        // Wire the model's completion hook to notifications once, at launch.
        timer.onPhaseCompleted = { finished in
            Notifications.post(for: finished)
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
- **GOTCHA**: `@State private var timer: PomodoroTimer` has no default value now; it is seeded in `init()` via `_timer = State(initialValue:)`. Keep `Image(systemName: "timer")` — Phase 6 changes it.
- **VALIDATE**: Validation 1 build.

### Task 4: Edit `Slice/MenuBarView.swift`
- **ACTION**: In the Start/Pause button action, the `else` branch currently reads:
```swift
                    } else {
                        timer.start()
                    }
```
Replace it with EXACTLY:
```swift
                    } else {
                        timer.start()
                        // First press asks macOS for notification permission;
                        // later presses return instantly with the saved answer.
                        Task { await Notifications.requestAuthorization() }
                    }
```
- **GOTCHA**: Nothing else in the file changes. `Task { }` inside a `@MainActor` view body inherits main-actor isolation; no `@Sendable` needed.
- **VALIDATE**: `grep -c "Notifications.requestAuthorization" Slice/MenuBarView.swift` prints `1`.

### Task 5: README status line
- **ACTION**: Replace the `**Status:**` line with EXACTLY:
```
**Status:** work in progress — Phase 4 of 7 (notifications). Timer works and notifies with a banner and sound when a phase ends. Settings, icon and a downloadable release are next.
```
- **VALIDATE**: `grep -c "Phase 4 of 7" README.md` prints `1`.

### Task 6: Regenerate, validate, commit, push
- **ACTION**: `xcodegen generate`, Validation Commands 1–5, then:
```sh
git add -A
git commit -m "feat: banner and sound when a phase ends, durations from UserDefaults

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
```
- **VALIDATE**: `git status --short` empty; `git log --oneline -1` shows the commit.

---

## Testing Strategy

### Unit Tests
| Test | Input | Expected Output | Edge Case? |
|---|---|---|---|
| workEndingSaysTakeABreak | `.work` | "Work done" / "Take a break." | — |
| breakEndingSaysBackToWork | `.shortBreak` | "Break over" / "Back to work when you're ready." | — |

### Edge Cases Checklist
- [x] Permission denied — `requestAuthorization` logs `.error`, timer unaffected
- [x] Missing defaults keys — falls back to 25/5
- [x] Two notifications in a row — UUID identifiers, never coalesced
- [ ] Do Not Disturb / Focus on — banner suppressed by the OS by design

---

## Validation Commands

Run from `/Users/reza/Slice`, in order.

### 1. Generate + build
```sh
xcodegen generate | tail -1
grep -c "Notifications" Slice.xcodeproj/project.pbxproj
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug build 2>&1 | grep -E "error:|warning:|BUILD" | grep -v -E "appintentsmetadataprocessor|Error Domain"
```
EXPECT: `Created project at /Users/reza/Slice/Slice.xcodeproj`, a number ≥ 4, then exactly `** BUILD SUCCEEDED **`.

### 2. Test
```sh
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug test 2>&1 | grep -E "✘|Test run with|TEST (SUCCEEDED|FAILED)" | grep -v "Error Domain"
```
EXPECT: `✔ Test run with 12 tests in 3 suites passed` and `** TEST SUCCEEDED **`.

### 3. Only the planned files changed
```sh
git status --short
```
EXPECT: `M README.md`, `M Slice.xcodeproj/project.pbxproj`, `M Slice/MenuBarView.swift`, `M Slice/SliceApp.swift`, `?? Slice/Notifications.swift`, `?? SliceTests/NotificationsTests.swift`. Nothing else.

### 4. End-to-end: 1-minute work phase posts a notification (takes ~80 s)
```sh
APP="$(xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR =/{print $3}')/Slice.app"
pkill -x Slice; sleep 1
defaults write com.rezaahmadn.Slice workMinutes -int 1
defaults write com.rezaahmadn.Slice breakMinutes -int 1
open "$APP"; sleep 4
osascript -e 'tell application "System Events" to tell process "Slice" to get name of every menu bar item of menu bar 2'
osascript <<'APPLESCRIPT'
tell application "System Events"
  tell process "Slice"
    if (count windows) = 0 then
      click menu bar item 1 of menu bar 2
      delay 1
    end if
    click button 1 of group 1 of window 1
  end tell
end tell
APPLESCRIPT
sleep 64
screencapture -x -R 700,0,812,200 /tmp/slice-banner.png
/usr/bin/log show --last 90s --predicate 'subsystem == "com.rezaahmadn.Slice"' --style compact 2>&1 | grep -v "^Timestamp"
pkill -x Slice
defaults delete com.rezaahmadn.Slice workMinutes
defaults delete com.rezaahmadn.Slice breakMinutes
defaults read com.rezaahmadn.Slice 2>&1 | grep -c "Minutes"
```
EXPECT: first line `01:00` (proves the defaults override). Log lines containing `Notification permission granted: true` and `Posted notification: Work done`. Final line `0` (defaults cleaned). Then Read `/tmp/slice-banner.png`: a macOS notification banner near the top-right reading "Work done / Take a break." (if it has already slid away, the log line is still the authoritative pass).

### 5. After commit and push
```sh
git status --short; git log --oneline -1
```
EXPECT: empty status; commit line containing `feat: banner and sound`.

---

## Acceptance Criteria
- [ ] Tasks 1–6 done
- [ ] Validations 1–5 match EXPECT
- [ ] `defaults read com.rezaahmadn.Slice` no longer contains `workMinutes`/`breakMinutes`
- [ ] Pushed

## Completion Checklist
- [ ] Files byte-identical to plan
- [ ] `PomodoroTimer.swift` and its tests untouched
- [ ] No `print`, `try!`, `fatalError`; no `.info` logging
- [ ] PRD Phase 4 row → `complete` (orchestrator)

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Permission somehow reset → `Notifications are not allowed` in log | L | Validation 4 fails | Stop and report; orchestrator re-grants |
| Validation 4 panel-click flake | L | `Can't get window 1` | Re-run Validation 4 once (it cleans up its own defaults) |
| Focus mode on | L | No banner visible, log still passes | Log line is authoritative |

## Notes
- Durations are read once at launch. Phase 5 makes them live via `@AppStorage` and updates the model.
- `onPhaseCompleted` runs on the main actor; `Notifications.post` is synchronous and cheap, so no `Task` wrapper is needed there.
