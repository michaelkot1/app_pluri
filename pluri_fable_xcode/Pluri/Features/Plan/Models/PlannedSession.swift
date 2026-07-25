import Foundation

/// A single workout within a week of a `GeneratedPlan` (M1-16).
///
/// For a **scheduled** plan (SPEC §3.2 Q9) the session is pinned to a
/// `weekday` and resolves to a concrete `date`; for a **flexible** plan both
/// are `nil` and the session is just "workout N of the week" until the user
/// assigns it a day on the calendar (SPEC §14 #37).
///
/// M3-03 extends the model with the persisted workout metadata
/// (`plan_workouts` columns) that Home / Plan / Calendar render — status,
/// type, color, global order, and planned duration — so a remote restore no
/// longer discards them.
nonisolated struct PlannedSession: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String

    /// 1-based index of this session within its week (1 = first workout).
    let indexInWeek: Int

    /// Pinned weekday for scheduled plans; `nil` for flexible plans.
    let weekday: Weekday?

    /// Concrete calendar date for scheduled plans; `nil` for flexible plans.
    let date: Date?

    /// Lifecycle state (`plan_workouts.status`). New plans start `scheduled`.
    let status: WorkoutStatus

    /// Discipline (`plan_workouts.workout_type`). v1 engine output is `weights`.
    let workoutType: WorkoutType

    /// Optional design-token key / color string persisted per workout
    /// (`plan_workouts.color`); `nil` means "use the type's default color".
    let color: String?

    /// Session focus code (`plan_workouts.focus`). `nil` for legacy rows
    /// written before M3-20 — UI then falls back to title/type color (#41d).
    let focus: SessionFocusCode?

    /// Stable global position across the whole plan (`plan_workouts.order_index`).
    let orderIndex: Int

    /// Planned wall-clock length (`plan_workouts.duration_minutes`).
    let durationMinutes: Int

    let exercises: [PlannedExercise]

    init(
        id: UUID = UUID(),
        title: String,
        indexInWeek: Int,
        weekday: Weekday?,
        date: Date?,
        status: WorkoutStatus = .scheduled,
        workoutType: WorkoutType = .weights,
        color: String? = nil,
        focus: SessionFocusCode? = nil,
        orderIndex: Int? = nil,
        durationMinutes: Int? = nil,
        exercises: [PlannedExercise]
    ) {
        self.id = id
        self.title = title
        self.indexInWeek = indexInWeek
        self.weekday = weekday
        self.date = date
        self.status = status
        self.workoutType = workoutType
        self.color = color
        self.focus = focus
        self.orderIndex = orderIndex ?? max(indexInWeek - 1, 0)
        self.durationMinutes = durationMinutes
            ?? Self.clampedDuration(Self.estimatedMinutes(for: exercises))
        self.exercises = exercises
    }

    /// Rough planned length: total sets across all exercises times the
    /// engine's per-set time budget (`PlanEngine.minutesPerSet`), rounded to
    /// whole minutes. A teaser figure, not a precise stopwatch.
    var estimatedMinutes: Int {
        Self.estimatedMinutes(for: exercises)
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

    private static func estimatedMinutes(for exercises: [PlannedExercise]) -> Int {
        let totalSets = exercises.reduce(0) { $0 + $1.sets }
        return Int((Double(totalSets) * PlanEngine.minutesPerSet).rounded())
    }

    /// Clamps a duration to the `plan_workouts.duration_minutes` CHECK range.
    static func clampedDuration(_ minutes: Int) -> Int {
        min(max(minutes, 10), 240)
    }
}
