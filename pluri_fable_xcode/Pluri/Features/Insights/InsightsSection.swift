import Foundation

/// Health subsections a Home tile can deep-link into (SPEC §5 "Today's Health").
/// Performance tab chips highlight the selected metric for M5-10 live insights
/// (SPEC §14 #61). Calories maps to active energy.
enum InsightsSection: String, CaseIterable, Hashable, Identifiable, Sendable {
    case general
    case steps
    case sleep
    case calories
    case activeHeartRate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "Overview"
        case .steps: "Steps"
        case .sleep: "Sleep"
        case .calories: "Calories"
        case .activeHeartRate: "Active Heart Rate"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "chart.line.uptrend.xyaxis"
        case .steps: "figure.walk"
        case .sleep: "bed.double.fill"
        case .calories: "flame.fill"
        case .activeHeartRate: "heart.fill"
        }
    }

    /// Maps chip selection to a single health metric; Overview has no metric filter.
    var healthMetric: HealthInsightsEngine.Metric? {
        switch self {
        case .general: nil
        case .steps: .steps
        case .sleep: .sleep
        case .calories: .calories
        case .activeHeartRate: .activeHeartRate
        }
    }
}
