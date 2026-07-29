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

    /// Original WorkoutX animated GIF. Kept as provenance only: the upstream
    /// host requires an `X-WorkoutX-Key` header the app must never ship, so no
    /// Pluri screen loads this URL (SPEC §14 #79).
    let imageURL: URL?

    /// Public CDN URL of Pluri's own mirrored MP4 loop — the media every
    /// exercise surface actually plays. `nil` until the mirror job
    /// (`Scripts/mirror_exercise_media.mjs`) has covered this exercise, in
    /// which case the UI shows a placeholder (SPEC §14 #79).
    let videoURL: URL?
}
