# Plan: Phase 2 — Timer Core

## Summary
Add the Pomodoro state machine, `PomodoroTimer`, as a pure model with no UI, plus a Swift Testing suite that drives it with synthetic dates. After this phase the app looks identical to Phase 1 (still shows static `25:00`); the difference is a tested, sleep-proof timer ready for Phase 3 to bind.

**Both files below were dry-run on this machine on 2026-09-15 against the Phase 1 skeleton: build succeeded with zero warnings, `✔ Test run with 10 tests in 2 suites passed`.** Copy them exactly.

## User Story
As Reza, I want a timer model that survives Mac sleep and is fully unit-tested, so that the UI phases only wire up views and never debug timing logic.

## Problem → Solution
Static `25:00` placeholder → `@MainActor @Observable` model with work/break phases, start/pause/reset, end-date-based ticking, auto work→break, break→idle, and a completion callback for Phase 4.

## Metadata
- **Complexity**: Small
- **Source PRD**: `.claude/PRPs/prds/slice.prd.md`
- **PRD Phase**: 2 — Timer core
- **Estimated Files**: 2 created, 1 regenerated (`Slice.xcodeproj/project.pbxproj`)

---

## UX Design
N/A — internal change. Menu bar still shows static `25:00` until Phase 3.

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| none | — | — | Model only |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `project.yml` | all | Confirms sources are globbed from `Slice/` and `SliceTests/` — new files need `xcodegen generate` |
| P0 | `SliceTests/SliceTests.swift` | all | TEST_STRUCTURE to mirror (`import Testing`, `@Test`, `#expect`) |
| P1 | `Slice/SliceApp.swift` | all | COMMENT_STYLE to mirror; do NOT modify it this phase |
| P1 | `.claude/PRPs/prds/slice.prd.md` | "Technical Approach" | Why end-date, why `@MainActor` |

## External Documentation

| Topic | Source | Key Takeaway |
|---|---|---|
| Observation | https://developer.apple.com/documentation/observation | `@Observable` class; SwiftUI re-renders on property change; no `@Published` needed |
| Swift Testing | https://developer.apple.com/documentation/testing | `@MainActor struct` suite is allowed; `#expect(a == b)` |
| Task.sleep | https://developer.apple.com/documentation/swift/task/sleep(for:tolerance:clock:) | `try? await Task.sleep(for: .seconds(1))` returns early on cancel |

Verified facts (from the dry run — treat as law):

KEY_INSIGHT: XcodeGen lists source files explicitly in `project.pbxproj`. Adding a `.swift` file WITHOUT re-running `xcodegen generate` leaves it out of the build silently.
APPLIES_TO: Task 3. Always regenerate and commit the regenerated `project.pbxproj`.

KEY_INSIGHT: `Task { [weak self] in ... }` created inside a `@MainActor` method inherits main-actor isolation; calling `self.tick()` inside compiles under Swift 6 strict concurrency with no warnings.
APPLIES_TO: `startTicking()`.

KEY_INSIGHT: A `@MainActor struct` test suite may store a non-Sendable closure into `timer.onPhaseCompleted` and mutate a captured local `var` — compiles clean in Swift 6.2.
APPLIES_TO: Tests.

KEY_INSIGHT: No `deinit` on the model. A `@MainActor` class's `deinit` is nonisolated in Swift 6 and cannot touch `tickTask` without errors. The `[weak self]` loop exits on its own once the model is freed.
APPLIES_TO: `PomodoroTimer`. Do not add a `deinit`.

---

## Patterns to Mirror

### NAMING_CONVENTION
// SOURCE: `Slice/MenuBarView.swift:1-5`, `SliceTests/SliceTests.swift:1-5`
One type per file, file named after the type. Tests: `<Type>Tests.swift`, `struct <Type>Tests`.

### COMMENT_STYLE
// SOURCE: `Slice/SliceApp.swift:3-4, 8-11`
```swift
/// The app's entry point. SwiftUI creates exactly one `SliceApp` and asks it for scenes.
/// Slice has no regular window — its only scene is the menu bar item.
...
        // `MenuBarExtra` puts an item in the macOS menu bar (macOS 13+).
        // The `label` closure is what you see in the bar; the main closure is the
```
`///` on every type and non-obvious member; `//` inside bodies explaining why or introducing a concept once.

### TEST_STRUCTURE
// SOURCE: `SliceTests/SliceTests.swift:1-10`
```swift
import Testing
@testable import Slice

struct SliceTests {
    @Test func placeholder() {
        #expect(true)
    }
}
```

### ERROR_HANDLING / LOGGING
None needed. Model has no failure paths. No `print`.

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `Slice/PomodoroTimer.swift` | CREATE | The model |
| `SliceTests/PomodoroTimerTests.swift` | CREATE | 9 behavioural tests |
| `Slice.xcodeproj/project.pbxproj` | REGENERATE | `xcodegen generate` picks up the two new files |
| `README.md` | UPDATE | Status line only: Phase 1 → Phase 2 |

## NOT Building
- Binding the menu bar label to `displayText` (Phase 3)
- Notifications inside `onPhaseCompleted` (Phase 4)
- Persisting durations (Phase 5)
- Long breaks, cycle counting, global hotkey (post-MVP)
- Any change to `SliceApp.swift` or `MenuBarView.swift`

---

## Step-by-Step Tasks

All commands run from `/Users/reza/Slice`. Use absolute paths.

### Task 1: Create `Slice/PomodoroTimer.swift`
- **ACTION**: Create the file with EXACTLY this content.
- **IMPLEMENT**:
```swift
import Foundation
import Observation

/// The Pomodoro state machine. Owns every piece of timer state; views only read it
/// and call `start()`, `pause()`, `reset()`.
///
/// `@MainActor` keeps all reads and writes on the main thread — what SwiftUI needs,
/// and what lets Swift 6 strict concurrency compile without `Sendable` errors.
/// `@Observable` (macOS 14+) makes SwiftUI views re-render when a property changes.
@MainActor
@Observable
final class PomodoroTimer {

    /// Which part of the Pomodoro cycle the timer is in.
    enum Phase: Equatable {
        case work
        case shortBreak

        /// Human-readable name for the UI.
        var title: String {
            switch self {
            case .work: "Work"
            case .shortBreak: "Break"
            }
        }
    }

    /// Whether the countdown is moving.
    enum State: Equatable {
        /// Nothing running; `remaining` shows the full phase length.
        case idle
        case running
        case paused
    }

    // MARK: - Configuration (Phase 5 makes these user-editable)

    /// Length of a work session, in seconds.
    var workDuration: TimeInterval
    /// Length of a break, in seconds.
    var breakDuration: TimeInterval

    // MARK: - Observable state

    private(set) var phase: Phase = .work
    private(set) var state: State = .idle
    /// Seconds left in the current phase. Never negative.
    private(set) var remaining: TimeInterval

    /// Called on the main actor each time a phase finishes, with the phase that ended.
    /// Phase 4 hooks notifications here.
    var onPhaseCompleted: ((Phase) -> Void)?

    // MARK: - Private

    /// Wall-clock moment the current phase ends. We store *this* instead of counting
    /// down a number so the timer stays correct after the Mac sleeps: every tick
    /// recomputes `remaining` from the real clock.
    private var endDate: Date?
    /// The background loop that calls `tick()` once a second while running.
    private var tickTask: Task<Void, Never>?

    init(workDuration: TimeInterval = 25 * 60, breakDuration: TimeInterval = 5 * 60) {
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.remaining = workDuration
    }

    // MARK: - Controls

    /// Starts an idle phase, or resumes a paused one.
    /// `now` is injectable so tests can drive time without waiting.
    func start(now: Date = .now) {
        guard state != .running else { return }
        endDate = now.addingTimeInterval(remaining)
        state = .running
        startTicking()
    }

    /// Freezes the countdown; `start()` resumes from the same point.
    func pause(now: Date = .now) {
        guard state == .running else { return }
        tick(now: now)
        stopTicking()
        endDate = nil
        state = .paused
    }

    /// Stops everything and returns to an idle work session at full length.
    func reset() {
        stopTicking()
        endDate = nil
        phase = .work
        state = .idle
        remaining = workDuration
    }

    // MARK: - Clock

    /// Recomputes `remaining` from the clock and handles phase completion.
    /// Internal (not private) so tests can call it with synthetic dates.
    func tick(now: Date = .now) {
        guard state == .running, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSince(now))
        if remaining == 0 {
            completePhase(now: now)
        }
    }

    /// "25:00"-style text for the menu bar. Rounds *up* so the display only drops
    /// to 24:59 once a full second has actually passed.
    var displayText: String {
        let totalSeconds = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func completePhase(now: Date) {
        let finished = phase
        switch finished {
        case .work:
            // The break starts by itself so you don't have to touch the timer.
            phase = .shortBreak
            remaining = breakDuration
            endDate = now.addingTimeInterval(breakDuration)
        case .shortBreak:
            // Back to an idle work session: starting the next one is a deliberate act.
            stopTicking()
            endDate = nil
            phase = .work
            state = .idle
            remaining = workDuration
        }
        onPhaseCompleted?(finished)
    }

    private func startTicking() {
        tickTask?.cancel()
        // A `Task` created inside a `@MainActor` method inherits main-actor isolation,
        // so calling `tick()` from it is safe. `[weak self]` lets the timer be freed
        // while the loop is asleep; the loop then exits on its next wake-up.
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.tick()
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }
}
```
- **MIRROR**: COMMENT_STYLE, NAMING_CONVENTION
- **IMPORTS**: `Foundation`, `Observation`
- **GOTCHA**: No `deinit`. Keep `tick(now:)` internal (not `private`) — tests call it. Keep `phase`, `state`, `remaining` as `private(set)`.
- **VALIDATE**: Build in Validation 2.

### Task 2: Create `SliceTests/PomodoroTimerTests.swift`
- **ACTION**: Create the file with EXACTLY this content.
- **IMPLEMENT**:
```swift
import Foundation
import Testing
@testable import Slice

/// Drives `PomodoroTimer` with synthetic dates so no test ever waits on real time.
/// `@MainActor` because the model is main-actor isolated.
@MainActor
struct PomodoroTimerTests {
    /// An arbitrary fixed instant; only differences between dates matter.
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func startsIdleWithFullWorkDuration() {
        let timer = PomodoroTimer()
        #expect(timer.phase == .work)
        #expect(timer.state == .idle)
        #expect(timer.remaining == 25 * 60)
        #expect(timer.displayText == "25:00")
    }

    @Test func countsDownFromTheClock() {
        let timer = PomodoroTimer()
        timer.start(now: t0)
        #expect(timer.state == .running)
        timer.tick(now: t0.addingTimeInterval(61))
        #expect(timer.remaining == 25 * 60 - 61)
        #expect(timer.displayText == "23:59")
    }

    @Test func displayRoundsUpToWholeSeconds() {
        let timer = PomodoroTimer()
        timer.start(now: t0)
        timer.tick(now: t0.addingTimeInterval(0.4))
        #expect(timer.displayText == "25:00")
        timer.tick(now: t0.addingTimeInterval(1))
        #expect(timer.displayText == "24:59")
    }

    @Test func workCompletionStartsBreakAutomatically() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4)
        var completed: [PomodoroTimer.Phase] = []
        timer.onPhaseCompleted = { completed.append($0) }
        timer.start(now: t0)
        timer.tick(now: t0.addingTimeInterval(10))
        #expect(timer.phase == .shortBreak)
        #expect(timer.state == .running)
        #expect(timer.remaining == 4)
        #expect(completed == [.work])
    }

    @Test func breakCompletionReturnsToIdleWork() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4)
        var completed: [PomodoroTimer.Phase] = []
        timer.onPhaseCompleted = { completed.append($0) }
        timer.start(now: t0)
        timer.tick(now: t0.addingTimeInterval(10))   // work -> break
        timer.tick(now: t0.addingTimeInterval(14))   // break -> idle work
        #expect(timer.phase == .work)
        #expect(timer.state == .idle)
        #expect(timer.remaining == 10)
        #expect(completed == [.work, .shortBreak])
    }

    @Test func pauseFreezesAndStartResumes() {
        let timer = PomodoroTimer(workDuration: 100, breakDuration: 4)
        timer.start(now: t0)
        timer.pause(now: t0.addingTimeInterval(5))
        #expect(timer.state == .paused)
        #expect(timer.remaining == 95)
        timer.tick(now: t0.addingTimeInterval(50))   // ignored while paused
        #expect(timer.remaining == 95)
        timer.start(now: t0.addingTimeInterval(50))
        timer.tick(now: t0.addingTimeInterval(51))
        #expect(timer.remaining == 94)
    }

    @Test func resetReturnsToIdleWorkAtFullLength() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4)
        timer.start(now: t0)
        timer.tick(now: t0.addingTimeInterval(10))   // now in break
        timer.reset()
        #expect(timer.phase == .work)
        #expect(timer.state == .idle)
        #expect(timer.remaining == 10)
    }

    @Test func survivesLongGapLikeSleep() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4)
        timer.start(now: t0)
        // Mac slept for 50 s: work is long over. The break starts from the moment we notice.
        timer.tick(now: t0.addingTimeInterval(50))
        #expect(timer.phase == .shortBreak)
        #expect(timer.state == .running)
        #expect(timer.remaining == 4)
    }

    @Test func startWhileRunningIsIgnored() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4)
        timer.start(now: t0)
        timer.tick(now: t0.addingTimeInterval(3))
        timer.start(now: t0.addingTimeInterval(3))   // must not restart the countdown
        timer.tick(now: t0.addingTimeInterval(4))
        #expect(timer.remaining == 6)
    }
}
```
- **MIRROR**: TEST_STRUCTURE
- **IMPORTS**: `Foundation`, `Testing`, `@testable import Slice`
- **GOTCHA**: Suite must be `@MainActor` because the model is. Keep `SliceTests.swift` (placeholder) — do not delete it.
- **VALIDATE**: Validation 3 reports 10 tests in 2 suites.

### Task 3: Regenerate the Xcode project
- **ACTION**: `xcodegen generate`
- **GOTCHA**: Without this the new files are not compiled and tests will report 1 test, not 10.
- **VALIDATE**: `grep -c "PomodoroTimer" Slice.xcodeproj/project.pbxproj` prints a number ≥ 2.

### Task 4: Update README status line
- **ACTION**: In `README.md`, replace the line starting with `**Status:**` with EXACTLY:
```
**Status:** work in progress — Phase 2 of 7 (timer core). The menu bar still shows a static `25:00`; the timer model is done and tested, the UI binds to it next.
```
- **VALIDATE**: `grep -c "Phase 2 of 7" README.md` prints `1`.

### Task 5: Validate, commit, push
- **ACTION**: Run Validation Commands 1–4, then:
```sh
git add -A
git commit -m "feat: PomodoroTimer model with sleep-proof ticking and tests

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
```
- **VALIDATE**: `git status --short` prints nothing; `git log --oneline -1` shows the commit.

---

## Testing Strategy

### Unit Tests (all in `PomodoroTimerTests`)
| Test | Input | Expected Output | Edge Case? |
|---|---|---|---|
| startsIdleWithFullWorkDuration | fresh model | idle, work, 1500 s, "25:00" | — |
| countsDownFromTheClock | start t0, tick t0+61 | remaining 1439, "23:59" | — |
| displayRoundsUpToWholeSeconds | tick +0.4, +1 | "25:00" then "24:59" | rounding |
| workCompletionStartsBreakAutomatically | work 10, tick +10 | break running, 4 s, callback [.work] | transition |
| breakCompletionReturnsToIdleWork | tick +10, +14 | work idle, 10 s, callback [.work,.shortBreak] | transition |
| pauseFreezesAndStartResumes | pause +5, tick +50, start +50, tick +51 | 95, 95, 94 | pause |
| resetReturnsToIdleWorkAtFullLength | reset mid-break | work idle 10 s | reset |
| survivesLongGapLikeSleep | work 10, tick +50 | break running 4 s | sleep |
| startWhileRunningIsIgnored | start twice | countdown not restarted | guard |

### Edge Cases Checklist
- [x] Sleep / long gap
- [x] Double start
- [x] Tick while paused / idle (ignored by guard)
- [x] Sub-second display rounding
- [ ] Duration changed while running — Phase 5 concern (takes effect on next `reset()`)

---

## Validation Commands

Run from `/Users/reza/Slice`, in order.

### 1. Generate
```sh
xcodegen generate
grep -c "PomodoroTimer" Slice.xcodeproj/project.pbxproj
```
EXPECT: `Created project at /Users/reza/Slice/Slice.xcodeproj`, then a number ≥ 2.

### 2. Build
```sh
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug build 2>&1 | grep -E "error:|warning:|BUILD" | grep -v appintentsmetadataprocessor
```
EXPECT: exactly one line: `** BUILD SUCCEEDED **`.

### 3. Test
```sh
xcodebuild -project Slice.xcodeproj -scheme Slice -configuration Debug test 2>&1 | grep -E "error:|✘|Test run with|TEST (SUCCEEDED|FAILED)"
```
EXPECT: `✔ Test run with 10 tests in 2 suites passed` and `** TEST SUCCEEDED **`. No `✘` lines.

### 4. Nothing else changed
```sh
git status --short
```
EXPECT: exactly these paths (order may vary): `M README.md`, `M Slice.xcodeproj/project.pbxproj`, `?? Slice/PomodoroTimer.swift`, `?? SliceTests/PomodoroTimerTests.swift`. Nothing else.

### 5. After commit and push
```sh
git status --short; git log --oneline -1
```
EXPECT: empty status, then the commit line containing `feat: PomodoroTimer model`.

---

## Acceptance Criteria
- [ ] Tasks 1–5 done
- [ ] Validation 1–5 match EXPECT
- [ ] Pushed to `origin/main`

## Completion Checklist
- [ ] Files match the plan byte-for-byte
- [ ] `SliceApp.swift`, `MenuBarView.swift`, `project.yml` untouched
- [ ] No `print`, `try!`, `fatalError`, no `deinit`
- [ ] PRD Phase 2 row → `complete` (orchestrator does this)

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Forgot `xcodegen generate` | M | Tests report 1 instead of 10 | Validation 1 grep + Validation 3 count |
| Everything else | Verified in dry run | — | Follow the plan exactly |

## Notes
- `onPhaseCompleted` receives the phase that *ended*. Phase 4 maps `.work` → "take a break", `.shortBreak` → "back to work".
- `displayText` is the single source of truth for the menu bar string; Phase 3 must use it, not reformat `remaining`.
- Break starts from the moment a long sleep gap is noticed, not from the theoretical work end. Simpler and matches what a person expects when they open the lid.
