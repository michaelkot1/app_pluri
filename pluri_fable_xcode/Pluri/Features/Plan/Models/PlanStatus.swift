import Foundation

/// Lifecycle state of a whole plan (M3-03), mirroring the `plans.status`
/// CHECK codes (`active` / `completed` / `archived`). Raw values are the DB
/// codes so mapping stays a plain rawValue round-trip.
nonisolated enum PlanStatus: String, CaseIterable, Sendable, Hashable {
    case active
    case completed
    case archived
}
