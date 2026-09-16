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

    /// What happened right after a phase finished. Drives the alert text.
    enum Transition: Equatable {
        /// A break started by itself (always, after work).
        case breakStarted
        /// The next work session started by itself: cycles are on and more remain.
        case workStarted
        /// Back to an idle work session; starting it is up to the user.
        case idle
        /// Back to idle because the last cycle just finished.
        case cyclesDone
    }

    // MARK: - Configuration (Phase 5 makes these user-editable)

    /// Length of a work session, in seconds.
    var workDuration: TimeInterval
    /// Length of a break, in seconds.
    var breakDuration: TimeInterval
    /// How many work+break rounds run back to back from one press of Start.
    /// `0` turns this off: one round, then idle, as before. No upper limit.
    var cycles: Int

    // MARK: - Observable state

    private(set) var phase: Phase = .work
    private(set) var state: State = .idle
    /// Seconds left in the current phase. Never negative.
    private(set) var remaining: TimeInterval
    /// Work sessions finished in the current run. Back to zero when the run
    /// ends or on Reset. In memory only: a relaunch starts over.
    private(set) var completedCycles = 0

    /// Called on the main actor each time a phase finishes, with the phase that
    /// ended and what happened next. Phase 4 hooks notifications here.
    var onPhaseCompleted: ((_ finished: Phase, _ next: Transition) -> Void)?

    // MARK: - Private

    /// Wall-clock moment the current phase ends. We store *this* instead of counting
    /// down a number so the timer stays correct after the Mac sleeps: every tick
    /// recomputes `remaining` from the real clock.
    private var endDate: Date?
    /// The background loop that calls `tick()` once a second while running.
    private var tickTask: Task<Void, Never>?

    init(workDuration: TimeInterval = 25 * 60, breakDuration: TimeInterval = 5 * 60, cycles: Int = 0) {
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.cycles = cycles
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
    /// Also forgets finished cycles: Reset means "start the run over".
    func reset() {
        completedCycles = 0
        returnToIdleWork()
    }

    /// Re-reads `workDuration` while idle, e.g. after a settings stepper moves.
    /// Unlike `reset()` this keeps the cycle count. Does nothing mid-session.
    func refreshIdleDuration() {
        guard state == .idle else { return }
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

    /// "Cycle 2 of 4" for the panel, or `nil` when cycles are off.
    /// During work it counts the session in progress; during a break, the one
    /// that just finished.
    var cycleLabel: String? {
        guard cycles > 0 else { return nil }
        let current = phase == .work ? completedCycles + 1 : completedCycles
        return "Cycle \(min(current, cycles)) of \(cycles)"
    }

    private func completePhase(now: Date) {
        let finished = phase
        let next: Transition
        switch finished {
        case .work:
            completedCycles += 1
            // The break starts by itself so you don't have to touch the timer.
            phase = .shortBreak
            remaining = breakDuration
            endDate = now.addingTimeInterval(breakDuration)
            next = .breakStarted
        case .shortBreak:
            // `<` rather than `!=` so lowering the setting mid-run ends the run at
            // the next break instead of running on until the counter wraps.
            if cycles > 0 && completedCycles < cycles {
                // More rounds to go: the next work session starts by itself.
                phase = .work
                remaining = workDuration
                endDate = now.addingTimeInterval(workDuration)
                next = .workStarted
            } else {
                // Back to an idle work session: starting the next one is a deliberate act.
                next = cycles > 0 ? .cyclesDone : .idle
                completedCycles = 0
                returnToIdleWork()
            }
        }
        onPhaseCompleted?(finished, next)
    }

    private func returnToIdleWork() {
        stopTicking()
        endDate = nil
        phase = .work
        state = .idle
        remaining = workDuration
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
