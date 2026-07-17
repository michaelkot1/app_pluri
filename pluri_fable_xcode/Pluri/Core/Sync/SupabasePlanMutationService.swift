import Foundation
import Supabase
import os.log

/// Live plan mutations (M3-05), composing `SupabaseService` like flush /
/// restore. Every statement runs through the authed client, so owner-only
/// RLS (M0-09) enforces access; the columns written are exactly the ones
/// `OnboardingSyncMapper.hydratePlan` preserves, so mutations survive the
/// M2-15 relaunch restore.
@MainActor
@Observable
final class SupabasePlanMutationService: PlanMutationServicing {
    private let supabaseService: SupabaseService
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "PlanMutation")

    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    private var client: SupabaseClient { supabaseService.client }

    func moveWorkout(planID: UUID, changedWorkouts: [PlanWorkoutInsertRow]) async throws {
        guard !changedWorkouts.isEmpty else { return }
        do {
            try await upsertWorkouts(changedWorkouts)
            logger.info("Moved workout in plan \(planID.uuidString, privacy: .public)")
        } catch {
            throw mapError(error)
        }
    }

    func addWorkout(
        planID: UUID,
        newWorkout: PlanWorkoutInsertRow,
        newExercises: [WorkoutExerciseInsertRow],
        reorderedWorkouts: [PlanWorkoutInsertRow]
    ) async throws {
        do {
            // The new workout row must exist before its exercises (FK), and
            // before sibling reorders so a failure leaves nothing dangling.
            try await upsertWorkouts([newWorkout])
            try await upsertExercises(newExercises)
            try await upsertWorkouts(reorderedWorkouts)
            logger.info("Added workout to plan \(planID.uuidString, privacy: .public)")
        } catch {
            throw mapError(error)
        }
    }

    func updatePlanSettings(planID: UUID, update: PlanSettingsUpdateRow) async throws {
        do {
            try await client
                .from("plans")
                .update(update)
                .eq("id", value: planID.uuidString)
                .execute()
        } catch {
            throw mapError(error)
        }
    }

    func updateProfileSettings(userID: UUID, update: ProfileSettingsUpdateRow) async throws {
        do {
            try await client
                .from("profiles")
                .update(update)
                .eq("id", value: userID.uuidString)
                .execute()
        } catch {
            throw mapError(error)
        }
    }

    func replaceRemainingWorkouts(
        planID: UUID,
        insertingWorkouts: [PlanWorkoutInsertRow],
        insertingExercises: [WorkoutExerciseInsertRow],
        updatingWorkouts: [PlanWorkoutInsertRow],
        deletingWorkoutIDs: [UUID]
    ) async throws {
        do {
            // Failure-safe sequencing (SPEC §14 #39): insert the replacement
            // rows first, then delete the replaced scheduled rows by explicit
            // ID. A mid-sequence failure can leave extra rows for a retry to
            // clean up, but never a half-deleted plan. A transactional RPC is
            // deferred to M3-14.
            try await upsertWorkouts(insertingWorkouts)
            try await upsertExercises(insertingExercises)
            try await upsertWorkouts(updatingWorkouts)

            if !deletingWorkoutIDs.isEmpty {
                let ids = deletingWorkoutIDs.map(\.uuidString)
                // plan_workouts → workout_exercises cascades on delete, but
                // delete children explicitly so we never depend on it.
                try await client
                    .from("workout_exercises")
                    .delete()
                    .in("plan_workout_id", values: ids)
                    .execute()
                try await client
                    .from("plan_workouts")
                    .delete()
                    .in("id", values: ids)
                    .execute()
            }
            logger.info("Replaced remaining workouts for plan \(planID.uuidString, privacy: .public)")
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Private

    private func upsertWorkouts(_ rows: [PlanWorkoutInsertRow]) async throws {
        guard !rows.isEmpty else { return }
        try await client
            .from("plan_workouts")
            .upsert(rows, onConflict: "id")
            .execute()
    }

    private func upsertExercises(_ rows: [WorkoutExerciseInsertRow]) async throws {
        guard !rows.isEmpty else { return }
        try await client
            .from("workout_exercises")
            .upsert(rows, onConflict: "id")
            .execute()
    }

    private func mapError(_ error: Error) -> PluriSyncError {
        let message = error.localizedDescription
        let lower = message.lowercased()
        if lower.localizedStandardContains("network")
            || lower.localizedStandardContains("offline")
            || lower.localizedStandardContains("internet") {
            return .networkUnavailable
        }
        logger.error("Plan mutation failed: \(message)")
        return .flushFailed(message)
    }
}
