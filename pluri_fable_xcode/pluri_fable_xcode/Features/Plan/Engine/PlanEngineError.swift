import Foundation

/// Failures the `PlanEngine` / plan-generation flow can surface. Kept typed so
/// the UI (M1-18) can react gently rather than dumping a raw string.
enum PlanEngineError: Error, Equatable, Sendable {
    /// The exercise catalog was empty — nothing cached and no successful
    /// WorkoutX refresh (e.g. offline on first run).
    case emptyCatalog

    /// After equipment ∩ injury filtering, no exercises remained to build a
    /// plan from (e.g. an extreme selection). The user can adjust answers.
    case noEligibleExercises

    var userFacingMessage: String {
        switch self {
        case .emptyCatalog:
            "We couldn't reach the exercise library. Check your connection and we'll try again."
        case .noEligibleExercises:
            "We couldn't find enough exercises for the equipment and injuries you told us about."
        }
    }
}
