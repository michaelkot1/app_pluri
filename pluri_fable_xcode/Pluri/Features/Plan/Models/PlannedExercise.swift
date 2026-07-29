import Foundation

/// One exercise slot inside a `PlannedSession`, with the sets/reps target the
/// `PlanEngine` (M1-16) assigned for the week it belongs to.
///
/// Carries a snapshot of the catalog fields the UI needs (name, equipment,
/// muscles, image) so a generated plan can be rendered — and later persisted
/// (PLAN §1.3 `workout_exercises`) — without re-fetching the catalog.
nonisolated struct PlannedExercise: Identifiable, Hashable, Sendable {
    let id: UUID
    let exerciseID: String
    let name: String
    let bodyPart: String
    let equipment: String
    let targetMuscle: String
    let secondaryMuscles: [String]

    /// Original WorkoutX GIF URL, snapshotted for provenance only — it is not
    /// loadable without the upstream API key (SPEC §14 #79).
    let imageURL: URL?

    /// Mirrored MP4 CDN URL for this exercise, snapshotted so an offline plan
    /// row can still play its demo (SPEC §14 #79).
    let videoURL: URL?

    /// Position within its session (0-based), so ordering is stable.
    let order: Int

    let sets: Int
    let reps: Int

    init(
        id: UUID = UUID(),
        exerciseID: String,
        name: String,
        bodyPart: String,
        equipment: String,
        targetMuscle: String,
        secondaryMuscles: [String],
        imageURL: URL?,
        videoURL: URL? = nil,
        order: Int,
        sets: Int,
        reps: Int
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.name = name
        self.bodyPart = bodyPart
        self.equipment = equipment
        self.targetMuscle = targetMuscle
        self.secondaryMuscles = secondaryMuscles
        self.imageURL = imageURL
        self.videoURL = videoURL
        self.order = order
        self.sets = sets
        self.reps = reps
    }

    /// "3 × 10" style set/rep summary for teasers and the debug dump.
    var setsRepsSummary: String {
        "\(sets) × \(reps)"
    }
}
