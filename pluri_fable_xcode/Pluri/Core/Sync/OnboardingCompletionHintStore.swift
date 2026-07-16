import Foundation

/// Local durability hint that onboarding/plan was flushed for a given user (interim until M2-18).
/// Remote `onboarding_completed` / active plan remains source of truth when restore succeeds online.
enum OnboardingCompletionHintStore {
    private static let keyPrefix = "pluri.onboarding.completedHint."

    static func markCompleted(userID: UUID) {
        UserDefaults.standard.set(true, forKey: key(for: userID))
    }

    static func isCompleted(userID: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: key(for: userID))
    }

    static func clear(userID: UUID) {
        UserDefaults.standard.removeObject(forKey: key(for: userID))
    }

    private static func key(for userID: UUID) -> String {
        keyPrefix + userID.uuidString
    }
}
