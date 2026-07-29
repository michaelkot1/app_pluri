import Foundation

/// A user-chosen daily target for one Health metric. Average heart rate is
/// intentionally excluded because higher is not inherently better.
nonisolated struct HealthMetricGoal: Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case steps
        case sleep
        case activeEnergy
    }

    var kind: Kind
    var target: Double
}
