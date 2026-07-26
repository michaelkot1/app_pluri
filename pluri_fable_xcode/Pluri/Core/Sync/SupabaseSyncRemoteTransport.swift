import Foundation
import Supabase
import os.log

/// Live Supabase transport for SyncEngine upserts (M4-03). LWW via
/// `onConflict: id`. Authed client so owner-only RLS applies.
@MainActor
final class SupabaseSyncRemoteTransport: SyncRemoteTransporting {
    private let supabaseService: SupabaseService
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "SyncTransport")

    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    private var client: SupabaseClient { supabaseService.client }

    func upsertSessions(_ rows: [WorkoutSessionUpsertRow]) async throws {
        guard !rows.isEmpty else { return }
        do {
            try await client
                .from("workout_sessions")
                .upsert(rows, onConflict: "id")
                .execute()
        } catch {
            throw mapError(error)
        }
    }

    func upsertSetLogs(_ rows: [SetLogUpsertRow]) async throws {
        guard !rows.isEmpty else { return }
        do {
            try await client
                .from("set_logs")
                .upsert(rows, onConflict: "id")
                .execute()
        } catch {
            throw mapError(error)
        }
    }

    func updatePlanWorkoutStatus(id: UUID, status: String) async throws {
        do {
            try await client
                .from("plan_workouts")
                .update(PlanWorkoutStatusUpdateRow(status: status))
                .eq("id", value: id.uuidString)
                .execute()
        } catch {
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> PluriSyncError {
        let message = error.localizedDescription
        let lower = message.lowercased()
        if lower.localizedStandardContains("network")
            || lower.localizedStandardContains("offline")
            || lower.localizedStandardContains("internet") {
            return .networkUnavailable
        }
        logger.error("Sync transport failed: \(message)")
        return .flushFailed(message)
    }
}
