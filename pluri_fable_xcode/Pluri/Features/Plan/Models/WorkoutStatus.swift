import Foundation

/// Lifecycle state of a planned workout (M3-03), mirroring the
/// `plan_workouts.status` CHECK codes (`scheduled` / `completed` / `skipped`).
/// Raw values are the DB codes so mapping stays a plain rawValue round-trip.
nonisolated enum WorkoutStatus: String, CaseIterable, Sendable, Hashable {
    case scheduled
    case completed
    case skipped

    /// Completed and skipped workouts are history: Manage Plan regeneration
    /// preserves them and only replaces `scheduled` ones (SPEC §14 #39).
    var isFinished: Bool { self != .scheduled }
}
