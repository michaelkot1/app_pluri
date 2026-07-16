import Foundation
import Supabase
import os.log

/// Live remote restore of profile + active plan children (M2-15).
@MainActor
@Observable
final class SupabaseRemotePlanRestoreService: RemotePlanRestoreServicing {
    private let supabaseService: SupabaseService
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "RemoteRestore")

    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    private var client: SupabaseClient { supabaseService.client }

    func restore(userID: UUID) async throws -> RestoredUserState? {
        do {
            let profiles: [ProfileUpsertRow] = try await client
                .from("profiles")
                .select()
                .eq("id", value: userID.uuidString)
                .limit(1)
                .execute()
                .value

            guard let profileRow = profiles.first else {
                logger.info("No profile row for \(userID.uuidString, privacy: .public)")
                return nil
            }

            let profile = OnboardingSyncMapper.hydrateProfile(from: profileRow)

            let plans: [PlanInsertRow] = try await client
                .from("plans")
                .select()
                .eq("user_id", value: userID.uuidString)
                .eq("status", value: "active")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            guard let planRow = plans.first else {
                return RestoredUserState(profile: profile, plan: nil)
            }

            let workouts: [PlanWorkoutInsertRow] = try await client
                .from("plan_workouts")
                .select()
                .eq("plan_id", value: planRow.id.uuidString)
                .order("order_index", ascending: true)
                .execute()
                .value

            let workoutIDs = workouts.map(\.id.uuidString)
            let exercises: [WorkoutExerciseInsertRow]
            if workoutIDs.isEmpty {
                exercises = []
            } else {
                exercises = try await client
                    .from("workout_exercises")
                    .select()
                    .in("plan_workout_id", values: workoutIDs)
                    .order("order_index", ascending: true)
                    .execute()
                    .value
            }

            let plan = OnboardingSyncMapper.hydratePlan(
                plan: planRow,
                workouts: workouts,
                exercises: exercises
            )
            return RestoredUserState(profile: profile, plan: plan)
        } catch let error as PluriSyncError {
            throw error
        } catch {
            let lower = error.localizedDescription.lowercased()
            if lower.localizedStandardContains("network")
                || lower.localizedStandardContains("offline")
                || lower.localizedStandardContains("internet") {
                throw PluriSyncError.networkUnavailable
            }
            logger.error("Restore failed: \(error.localizedDescription)")
            throw PluriSyncError.restoreFailed(error.localizedDescription)
        }
    }
}
