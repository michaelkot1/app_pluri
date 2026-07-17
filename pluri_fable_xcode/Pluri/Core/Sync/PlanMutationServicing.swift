import Foundation

/// Persists authenticated plan mutations for Calendar / Manage Plan (M3-05).
///
/// The write path mirrors flush (M2-14): rows built by `OnboardingSyncMapper`
/// are written through the authed Supabase client, so owner-only RLS (M0-09)
/// applies to every statement, and columns match exactly what
/// `hydratePlan` reads back on relaunch restore (M2-15).
///
/// Callers (the `PlanStore`) apply the domain change optimistically first,
/// then await these methods; a thrown error signals the store to roll back.
@MainActor
protocol PlanMutationServicing: AnyObject {
    /// Persists a workout move: upserts the moved workout's row plus any
    /// sibling rows whose order shifted during renormalization.
    func moveWorkout(planID: UUID, changedWorkouts: [PlanWorkoutInsertRow]) async throws

    /// Persists an added (cloned) workout: inserts the new workout + exercise
    /// rows (new IDs, SPEC §14 #38) and upserts any reordered siblings.
    func addWorkout(
        planID: UUID,
        newWorkout: PlanWorkoutInsertRow,
        newExercises: [WorkoutExerciseInsertRow],
        reorderedWorkouts: [PlanWorkoutInsertRow]
    ) async throws

    /// Updates `plans` metadata fields edited by Manage Plan (§6.2).
    func updatePlanSettings(planID: UUID, update: PlanSettingsUpdateRow) async throws

    /// Updates the `profiles` fields edited by Manage Plan (goal, dates /
    /// length, training days, session duration, units).
    func updateProfileSettings(userID: UUID, update: ProfileSettingsUpdateRow) async throws

    /// Replaces the remaining unfinished workouts per SPEC §14 #39, sequenced
    /// failure-safe: **insert** replacement workouts + exercises (and upsert
    /// preserved rows whose order shifted) first, then **delete** the old
    /// scheduled rows by explicit ID. A mid-sequence failure can leave extra
    /// rows for a retry to clean up, but never a half-deleted plan.
    func replaceRemainingWorkouts(
        planID: UUID,
        insertingWorkouts: [PlanWorkoutInsertRow],
        insertingExercises: [WorkoutExerciseInsertRow],
        updatingWorkouts: [PlanWorkoutInsertRow],
        deletingWorkoutIDs: [UUID]
    ) async throws
}
