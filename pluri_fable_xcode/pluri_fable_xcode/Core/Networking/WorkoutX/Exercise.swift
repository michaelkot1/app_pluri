import Foundation

/// Domain model for a single exercise in the catalog.
///
/// Intentionally decoupled from WorkoutX's wire format (`WorkoutXExerciseDTO`)
/// so a different exercise database could be swapped in behind
/// `WorkoutXClient` per PLAN §3.
struct Exercise: Identifiable, Hashable, Sendable {
    let id: String
    let name: String

    /// Injury-relevant body region (SPEC §3.2 Q7 uses this same taxonomy).
    let bodyPart: String
    let equipment: String
    let targetMuscle: String
    let secondaryMuscles: [String]
    let instructions: [String]

    /// Animated GIF/image demonstrating the exercise.
    let imageURL: URL?

    /// A video of a person performing the exercise (SPEC §8's image ↔ video
    /// toggle). The live WorkoutX API has no video field today — see
    /// `Core/Networking/WorkoutX/README.md`. Kept optional so a future
    /// provider or WorkoutX tier can populate it without a model change.
    let videoURL: URL?
}
