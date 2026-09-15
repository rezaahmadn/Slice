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
