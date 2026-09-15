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

    @Test func newWorkDurationShowsAfterResetWhileIdle() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4)
        timer.workDuration = 20   // what SettingsView does when the stepper moves
        timer.reset()
        #expect(timer.remaining == 20)
        #expect(timer.displayText == "00:20")
    }
}
