import Foundation
import Supabase
import os.log

/// Live flush: profile upsert + plan / workouts / exercises insert with retries (M2-14).
@MainActor
@Observable
final class SupabaseOnboardingFlushService: OnboardingFlushServicing {
    private let supabaseService: SupabaseService
    private let maxAttempts = 3
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "OnboardingFlush")

    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    private var client: SupabaseClient { supabaseService.client }

    func flush(userID: UUID, answers: OnboardingAnswers, plan: GeneratedPlan) async throws {
        let profile = try OnboardingSyncMapper.profileRow(userID: userID, answers: answers)
        let tree = OnboardingSyncMapper.planTree(userID: userID, plan: plan)
        let checkpoint = FlushCheckpointStore.Checkpoint(
            userID: userID,
            profile: profile,
            planTree: FlushCheckpointStore.PlanTreeCheckpoint(
                plan: tree.plan,
                workouts: tree.workouts,
                exercises: tree.exercises
            ),
            savedAt: .now
        )
        FlushCheckpointStore.save(checkpoint)

        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                try await write(profile: profile, tree: tree)
                FlushCheckpointStore.clear()
                OnboardingCompletionHintStore.markCompleted(userID: userID)
                logger.info("Flushed profile + plan for user \(userID.uuidString, privacy: .public)")
                return
            } catch {
                lastError = error
                logger.error("Flush attempt \(attempt) failed: \(error.localizedDescription)")
                if attempt < maxAttempts {
                    try? await Task.sleep(for: .seconds(Double(attempt) * 0.6))
                }
            }
        }

        throw mapError(lastError)
    }

    /// Retries a previously checkpointed flush (e.g. after relaunch).
    @discardableResult
    func retryPendingCheckpointIfNeeded() async throws -> Bool {
        guard let checkpoint = FlushCheckpointStore.load() else { return false }
        let tree = PlanTreeInsert(
            plan: checkpoint.planTree.plan,
            workouts: checkpoint.planTree.workouts,
            exercises: checkpoint.planTree.exercises
        )
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                try await write(profile: checkpoint.profile, tree: tree)
                FlushCheckpointStore.clear()
                OnboardingCompletionHintStore.markCompleted(userID: checkpoint.userID)
                return true
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try? await Task.sleep(for: .seconds(Double(attempt) * 0.6))
                }
            }
        }
        throw mapError(lastError)
    }

    private func write(profile: ProfileUpsertRow, tree: PlanTreeInsert) async throws {
        try await client
            .from("profiles")
            .upsert(profile, onConflict: "id")
            .execute()

        try await client
            .from("plans")
            .upsert(tree.plan, onConflict: "id")
            .execute()

        if !tree.workouts.isEmpty {
            try await client
                .from("plan_workouts")
                .upsert(tree.workouts, onConflict: "id")
                .execute()
        }

        if !tree.exercises.isEmpty {
            try await client
                .from("workout_exercises")
                .upsert(tree.exercises, onConflict: "id")
                .execute()
        }
    }

    private func mapError(_ error: Error?) -> PluriSyncError {
        let message = error?.localizedDescription ?? ""
        let lower = message.lowercased()
        if lower.localizedStandardContains("network")
            || lower.localizedStandardContains("offline")
            || lower.localizedStandardContains("internet") {
            return .networkUnavailable
        }
        return .flushFailed(message)
    }
}
