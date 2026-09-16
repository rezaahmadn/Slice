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
        timer.onPhaseCompleted = { finished, _ in completed.append(finished) }
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
        timer.onPhaseCompleted = { finished, _ in completed.append(finished) }
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

    // MARK: - Cycles (Phase 10)

    @Test func cyclesAutoStartTheNextWorkSession() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4, cycles: 2)
        var transitions: [PomodoroTimer.Transition] = []
        timer.onPhaseCompleted = { _, next in transitions.append(next) }
        timer.start(now: t0)
        timer.tick(now: t0.addingTimeInterval(10))   // work 1 -> break
        #expect(timer.completedCycles == 1)
        timer.tick(now: t0.addingTimeInterval(14))   // break -> work 2, by itself
        #expect(timer.phase == .work)
        #expect(timer.state == .running)
        #expect(timer.remaining == 10)
        #expect(transitions == [.breakStarted, .workStarted])
    }

    @Test func lastCycleEndsIdleWithCyclesDone() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4, cycles: 2)
        var transitions: [PomodoroTimer.Transition] = []
        timer.onPhaseCompleted = { _, next in transitions.append(next) }
        timer.start(now: t0)
        timer.tick(now: t0.addingTimeInterval(10))   // work 1 -> break
        timer.tick(now: t0.addingTimeInterval(14))   // break -> work 2
        timer.tick(now: t0.addingTimeInterval(24))   // work 2 -> break
        timer.tick(now: t0.addingTimeInterval(28))   // final break -> idle
        #expect(timer.phase == .work)
        #expect(timer.state == .idle)
        #expect(timer.remaining == 10)
        #expect(timer.completedCycles == 0)
        #expect(transitions == [.breakStarted, .workStarted, .breakStarted, .cyclesDone])
    }

    @Test func zeroCyclesMeansOneRoundThenIdle() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4, cycles: 0)
        var transitions: [PomodoroTimer.Transition] = []
        timer.onPhaseCompleted = { _, next in transitions.append(next) }
        timer.start(now: t0)
        timer.tick(now: t0.addingTimeInterval(10))
        timer.tick(now: t0.addingTimeInterval(14))
        #expect(timer.state == .idle)
        #expect(timer.completedCycles == 0)
        #expect(timer.cycleLabel == nil)
        #expect(transitions == [.breakStarted, .idle])
    }

    @Test func resetForgetsCompletedCycles() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4, cycles: 4)
        timer.start(now: t0)
        timer.tick(now: t0.addingTimeInterval(10))   // 1 done, in break
        timer.reset()
        #expect(timer.completedCycles == 0)
        #expect(timer.cycleLabel == "Cycle 1 of 4")
    }

    @Test func loweringCyclesBelowCompletedEndsRunAtNextBreak() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4, cycles: 4)
        var transitions: [PomodoroTimer.Transition] = []
        timer.onPhaseCompleted = { _, next in transitions.append(next) }
        timer.start(now: t0)
        timer.tick(now: t0.addingTimeInterval(10))   // work 1 -> break
        timer.tick(now: t0.addingTimeInterval(14))   // -> work 2
        timer.tick(now: t0.addingTimeInterval(24))   // work 2 -> break
        timer.tick(now: t0.addingTimeInterval(28))   // -> work 3
        timer.cycles = 2   // what SettingsView does when the field changes
        timer.tick(now: t0.addingTimeInterval(38))   // work 3 -> break
        timer.tick(now: t0.addingTimeInterval(42))   // 3 >= 2: run ends
        #expect(timer.state == .idle)
        #expect(transitions.last == .cyclesDone)
    }

    @Test func refreshIdleDurationKeepsCycleCount() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4, cycles: 4)
        timer.start(now: t0)
        timer.tick(now: t0.addingTimeInterval(10))   // work 1 -> break
        timer.pause(now: t0.addingTimeInterval(12))  // 1 done, paused mid-break
        timer.workDuration = 20
        timer.refreshIdleDuration()                  // not idle: must not touch the countdown
        #expect(timer.remaining == 2)
        #expect(timer.completedCycles == 1)
        timer.reset()
        timer.workDuration = 30
        timer.refreshIdleDuration()                  // idle: picks up the new length
        #expect(timer.remaining == 30)
    }

    @Test func cycleLabelCountsTheCurrentCycle() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4, cycles: 4)
        #expect(timer.cycleLabel == "Cycle 1 of 4")
        timer.start(now: t0)
        timer.tick(now: t0.addingTimeInterval(10))   // in break after cycle 1
        #expect(timer.cycleLabel == "Cycle 1 of 4")
        timer.tick(now: t0.addingTimeInterval(14))   // cycle 2 running
        #expect(timer.cycleLabel == "Cycle 2 of 4")
    }

    @Test func cycleCountHasNoUpperLimit() {
        let timer = PomodoroTimer(workDuration: 10, breakDuration: 4, cycles: 1_000_000)
        timer.start(now: t0)
        timer.tick(now: t0.addingTimeInterval(10))
        timer.tick(now: t0.addingTimeInterval(14))
        #expect(timer.phase == .work)
        #expect(timer.state == .running)
        #expect(timer.cycleLabel == "Cycle 2 of 1000000")
    }
}
