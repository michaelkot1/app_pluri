import Foundation

/// Display state for the Plan page's top plan card (M3-10 / SPEC §6):
/// goal/plan name, end date, and the "Weeks Completed 1/6" tracker.
nonisolated struct PlanCardModel: Equatable, Sendable {
    var title: String
    var endDateText: String
    var completedWeeks: Int
    var totalWeeks: Int

    /// The "1/6" tracker fraction.
    var trackerText: String { "\(completedWeeks)/\(totalWeeks)" }

    /// Tracker progress in 0...1 for the progress bar.
    var progress: Double {
        guard totalWeeks > 0 else { return 0 }
        return Double(completedWeeks) / Double(totalWeeks)
    }
}
