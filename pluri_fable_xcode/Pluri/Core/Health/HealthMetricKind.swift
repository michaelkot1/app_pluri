import Foundation

/// The four HealthKit read metrics Pluri consumes (Home tiles, Insights, Pluri Score).
/// Used to describe *which* categories Pluri can actually read after a prompt, since
/// HealthKit never reports per-type read grants (SPEC §14 #57b / #78).
enum HealthMetricKind: String, CaseIterable, Sendable {
    case steps
    case sleep
    case heartRate
    case activeEnergy

    /// User-facing name, matching the category names in the Health app.
    var title: String {
        switch self {
        case .steps: "Steps"
        case .sleep: "Sleep"
        case .heartRate: "Heart Rate"
        case .activeEnergy: "Active Energy"
        }
    }

    var snapshotValue: KeyPath<HealthDaySnapshot, Double?> {
        switch self {
        case .steps: \.stepCount
        case .sleep: \.sleepHours
        case .heartRate: \.averageHeartRateBPM
        case .activeEnergy: \.activeEnergyKilocalories
        }
    }
}
