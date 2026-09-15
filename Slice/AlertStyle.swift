import Foundation

/// How Slice gets your attention when a phase ends.
/// Stored in `UserDefaults` under `alertStyle` as its raw string.
enum AlertStyle: String, CaseIterable {
    /// A normal macOS notification banner with one sound.
    case banner
    /// The banner plus a floating window and a looping sound until dismissed.
    case alarm

    static let defaultsKey = "alertStyle"

    /// Reads the saved style; anything missing or unknown falls back to `.banner`.
    static func load(from defaults: UserDefaults = .standard) -> AlertStyle {
        guard let raw = defaults.string(forKey: defaultsKey) else { return .banner }
        return AlertStyle(rawValue: raw) ?? .banner
    }
}
