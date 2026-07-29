import Foundation
import Observation

/// Session + UserDefaults gate for the Plan-page Apple Health soft nudge
/// (SPEC §14 Plan HealthKit nudge — in-app only, never a push notification).
@MainActor
@Observable
final class PlanHealthKitNudgeController {
    static let dontAskAgainDefaultsKey = "pluri.healthKit.planNudge.dontAskAgain"

    private let defaults: UserDefaults
    private(set) var dismissedThisSession = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var dontAskAgain: Bool {
        defaults.bool(forKey: Self.dontAskAgainDefaultsKey)
    }

    /// Show for `.notDetermined` (Connect) or `.denied` (Settings guidance).
    /// Hidden when connected / unavailable, dismissed this session, or "don't ask again".
    func shouldShow(for status: HealthKitReadAuthorizationStatus) -> Bool {
        guard !dismissedThisSession, !dontAskAgain else { return false }
        switch status {
        case .notDetermined, .denied:
            return true
        case .authorized, .unavailable:
            return false
        }
    }

    func dismissForSession() {
        dismissedThisSession = true
    }

    func setDontAskAgain() {
        defaults.set(true, forKey: Self.dontAskAgainDefaultsKey)
        dismissedThisSession = true
    }
}
