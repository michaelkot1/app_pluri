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
    let imageURL: URL?

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
        self.order = order
        self.sets = sets
        self.reps = reps
    }

    /// "3 × 10" style set/rep summary for teasers and the debug dump.
    var setsRepsSummary: String {
        "\(sets) × \(reps)"
    }
}
