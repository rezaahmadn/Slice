import Foundation
import Testing
@testable import Slice

/// Uses a throwaway `UserDefaults` suite so tests never touch real preferences.
struct AlertStyleTests {
    private func freshDefaults() -> UserDefaults {
        let name = "AlertStyleTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func missingKeyMeansBanner() {
        #expect(AlertStyle.load(from: freshDefaults()) == .banner)
    }

    @Test func savedAlarmIsRead() {
        let d = freshDefaults()
        d.set("alarm", forKey: AlertStyle.defaultsKey)
        #expect(AlertStyle.load(from: d) == .alarm)
    }

    @Test func unknownValueFallsBackToBanner() {
        let d = freshDefaults()
        d.set("klaxon", forKey: AlertStyle.defaultsKey)
        #expect(AlertStyle.load(from: d) == .banner)
    }
}
