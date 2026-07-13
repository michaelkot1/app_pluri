import Foundation

/// A single workout within a week of a `GeneratedPlan` (M1-16).
///
/// For a **scheduled** plan (SPEC §3.2 Q9) the session is pinned to a
/// `weekday` and resolves to a concrete `date`; for a **flexible** plan both
/// are `nil` and the session is just "workout N of the week".
nonisolated struct PlannedSession: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String

    /// 1-based index of this session within its week (1 = first workout).
    let indexInWeek: Int

    /// Pinned weekday for scheduled plans; `nil` for flexible plans.
    let weekday: Weekday?

    /// Concrete calendar date for scheduled plans; `nil` for flexible plans.
    let date: Date?

    let exercises: [PlannedExercise]

    init(
        id: UUID = UUID(),
        title: String,
        indexInWeek: Int,
        weekday: Weekday?,
        date: Date?,
        exercises: [PlannedExercise]
    ) {
        self.id = id
        self.title = title
        self.indexInWeek = indexInWeek
        self.weekday = weekday
        self.date = date
        self.exercises = exercises
    }

    /// Rough planned length: total sets across all exercises times the
    /// engine's per-set time budget (`PlanEngine.minutesPerSet`), rounded to
    /// whole minutes. A teaser figure, not a precise stopwatch.
    var estimatedMinutes: Int {
        let totalSets = exercises.reduce(0) { $0 + $1.sets }
        return Int((Double(totalSets) * PlanEngine.minutesPerSet).rounded())
    }

    /// The distinct equipment this session needs (SPEC §7 "equipment needed").
    var equipmentNeeded: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for exercise in exercises where seen.insert(exercise.equipment).inserted {
            ordered.append(exercise.equipment)
        }
        return ordered
    }
}
