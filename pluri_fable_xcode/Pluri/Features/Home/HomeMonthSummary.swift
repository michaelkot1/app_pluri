import Foundation

/// The Home month header (M3-07 / SPEC §14 #41): the month's name + year and
/// a completion fraction among that month's **dated** workouts. No metrics
/// engine — just counts.
nonisolated struct HomeMonthSummary: Equatable, Sendable {
    /// e.g. "July 2026".
    var title: String
    /// Dated workouts in the month with `status == .completed`.
    var completedCount: Int
    /// All dated workouts in the month.
    var totalCount: Int

    /// e.g. "3 of 8 done"; `nil` when the month has no dated workouts.
    var completionText: String? {
        guard totalCount > 0 else { return nil }
        return "\(completedCount) of \(totalCount) done"
    }
}
