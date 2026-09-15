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
