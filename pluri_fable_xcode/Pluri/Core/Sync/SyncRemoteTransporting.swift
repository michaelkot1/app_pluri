import Foundation

/// Remote write surface for SyncEngine (M4-03 + M7-07 favorites + M7-11 food logs).
/// Production uses Supabase; tests inject a mock that records upserts / can fail.
@MainActor
protocol SyncRemoteTransporting: AnyObject {
    func upsertSessions(_ rows: [WorkoutSessionUpsertRow]) async throws
    func upsertSetLogs(_ rows: [SetLogUpsertRow]) async throws
    func updatePlanWorkoutStatus(id: UUID, status: String) async throws
    func upsertRecipeFavorites(_ rows: [RecipeFavoriteUpsertRow]) async throws
    func deleteRecipeFavorites(ids: [UUID]) async throws
    func upsertFoodLogs(_ rows: [FoodLogUpsertRow]) async throws
    func deleteFoodLogs(ids: [UUID]) async throws
}

/// In-memory transport for SyncEngine unit tests.
@MainActor
final class MockSyncRemoteTransport: SyncRemoteTransporting {
    struct PlanStatusCall: Equatable {
        var id: UUID
        var status: String
    }

    var nextError: PluriSyncError?
    private(set) var sessionUpserts: [[WorkoutSessionUpsertRow]] = []
    private(set) var setLogUpserts: [[SetLogUpsertRow]] = []
    private(set) var planStatusCalls: [PlanStatusCall] = []
    private(set) var recipeFavoriteUpserts: [[RecipeFavoriteUpsertRow]] = []
    private(set) var recipeFavoriteDeletes: [[UUID]] = []
    private(set) var foodLogUpserts: [[FoodLogUpsertRow]] = []
    private(set) var foodLogDeletes: [[UUID]] = []

    func upsertSessions(_ rows: [WorkoutSessionUpsertRow]) async throws {
        try throwIfNeeded()
        sessionUpserts.append(rows)
    }

    func upsertSetLogs(_ rows: [SetLogUpsertRow]) async throws {
        try throwIfNeeded()
        setLogUpserts.append(rows)
    }

    func updatePlanWorkoutStatus(id: UUID, status: String) async throws {
        try throwIfNeeded()
        planStatusCalls.append(PlanStatusCall(id: id, status: status))
    }

    func upsertRecipeFavorites(_ rows: [RecipeFavoriteUpsertRow]) async throws {
        try throwIfNeeded()
        recipeFavoriteUpserts.append(rows)
    }

    func deleteRecipeFavorites(ids: [UUID]) async throws {
        try throwIfNeeded()
        recipeFavoriteDeletes.append(ids)
    }

    func upsertFoodLogs(_ rows: [FoodLogUpsertRow]) async throws {
        try throwIfNeeded()
        foodLogUpserts.append(rows)
    }

    func deleteFoodLogs(ids: [UUID]) async throws {
        try throwIfNeeded()
        foodLogDeletes.append(ids)
    }

    private func throwIfNeeded() throws {
        if let nextError {
            self.nextError = nil
            throw nextError
        }
    }
}
