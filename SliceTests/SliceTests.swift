import Testing
@testable import Slice

/// Smoke test proving the test target builds and links against the app.
/// Phase 2 adds real tests for `PomodoroTimer` in their own file.
struct SliceTests {
    @Test func placeholder() {
        #expect(true)
    }
}
