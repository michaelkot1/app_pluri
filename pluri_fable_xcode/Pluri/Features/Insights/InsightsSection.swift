import Foundation

/// Sections of the Insights page a Home health tile can deep-link into
/// (SPEC §5 "Today's Health"). Live metrics arrive with HealthKit in M5;
/// until then each section renders an honest placeholder.
enum InsightsSection: String, CaseIterable, Hashable, Identifiable, Sendable {
    case general
    case steps
    case sleep
    case activeHeartRate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "Overview"
        case .steps: "Steps"
        case .sleep: "Sleep"
        case .activeHeartRate: "Active Heart Rate"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "chart.line.uptrend.xyaxis"
        case .steps: "figure.walk"
        case .sleep: "bed.double.fill"
        case .activeHeartRate: "heart.fill"
        }
    }

    /// Honest placeholder copy — no invented data (M3-06/M3-08).
    var placeholderMessage: String {
        switch self {
        case .general:
            "Performance trends and health insights arrive in a later update."
        case .steps:
            "Step averages, trends, and how to improve arrive once Apple Health connects in a later update."
        case .sleep:
            "Sleep trends against your own baseline arrive once Apple Health connects in a later update."
        case .activeHeartRate:
            "Active heart-rate zones and trends arrive once Apple Health connects in a later update."
        }
    }
}
