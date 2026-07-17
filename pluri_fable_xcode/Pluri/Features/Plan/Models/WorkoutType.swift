import Foundation

/// Discipline of a planned workout (M3-03), mirroring the
/// `plan_workouts.workout_type` CHECK codes (`weights` / `cardio` /
/// `flexibility`). v1 plans generate `weights` only (SPEC §1.1); the other
/// cases exist so restored v2 data survives the round-trip.
nonisolated enum WorkoutType: String, CaseIterable, Sendable, Hashable {
    case weights
    case cardio
    case flexibility

    /// User-facing discipline name (Home day cards, week cards).
    var title: String {
        switch self {
        case .weights: "Weights"
        case .cardio: "Cardio"
        case .flexibility: "Flexibility"
        }
    }
}
