import Foundation

/// Top-level Insights tabs (SPEC §9): Performance and Workouts.
enum InsightsPrimaryTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case performance
    case workouts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .performance: "Performance"
        case .workouts: "Workouts"
        }
    }
}
