import Testing
@testable import Slice

/// Only the pure text mapping is unit-tested; actual delivery is checked by hand.
struct NotificationsTests {
    @Test func workEndingSaysTakeABreak() {
        let c = Notifications.content(for: .work, next: .breakStarted)
        #expect(c.title == "Work done")
        #expect(c.body == "Take a break.")
    }

    @Test func breakEndingSaysBackToWork() {
        let c = Notifications.content(for: .shortBreak, next: .idle)
        #expect(c.title == "Break over")
        #expect(c.body == "Back to work when you're ready.")
    }

    @Test func breakEndingIntoNextCycleSaysSo() {
        let c = Notifications.content(for: .shortBreak, next: .workStarted)
        #expect(c.title == "Break over")
        #expect(c.body == "Next work session is running.")
    }

    @Test func lastBreakEndingSaysAllCyclesDone() {
        let c = Notifications.content(for: .shortBreak, next: .cyclesDone)
        #expect(c.title == "All cycles done")
        #expect(c.body == "Start again when you're ready.")
    }
}
