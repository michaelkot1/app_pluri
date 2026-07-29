import Foundation

/// User-scoped, on-device persistence for optional Health goals.
///
/// Goals stay local for now and are only created after explicit confirmation;
/// the store never invents a default target.
@MainActor
final class HealthMetricGoalStore {
    private let defaults: UserDefaults
    private let keyPrefix = "pluri.health-goal"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func goal(for kind: HealthMetricGoal.Kind, userID: String?) -> HealthMetricGoal? {
        guard let key = key(for: kind, userID: userID),
              let number = defaults.object(forKey: key) as? NSNumber,
              number.doubleValue > 0
        else {
            return nil
        }
        return HealthMetricGoal(kind: kind, target: number.doubleValue)
    }

    func setGoal(_ target: Double, for kind: HealthMetricGoal.Kind, userID: String?) {
        guard target.isFinite, target > 0, let key = key(for: kind, userID: userID) else {
            return
        }
        defaults.set(target, forKey: key)
    }

    func removeGoal(for kind: HealthMetricGoal.Kind, userID: String?) {
        guard let key = key(for: kind, userID: userID) else { return }
        defaults.removeObject(forKey: key)
    }

    private func key(for kind: HealthMetricGoal.Kind, userID: String?) -> String? {
        guard let userID, !userID.isEmpty else { return nil }
        return "\(keyPrefix).\(userID).\(kind.rawValue)"
    }
}
