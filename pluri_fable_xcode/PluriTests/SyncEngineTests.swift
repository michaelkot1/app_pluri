import Foundation
import SwiftData
import Testing
@testable import Pluri

/// M4-03 — SyncEngine: pending bookkeeping, LWW upserts via mock transport,
/// needsSync cleared on success / retained on failure, completed sessions
/// push plan workout status (SPEC §14 #52).
@Suite("SyncEngine")
@MainActor
struct SyncEngineTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            CachedExercise.self,
            ExerciseCatalogSyncState.self,
            WorkoutSessionRecord.self,
            SetLogRecord.self,
            RecipeFavoriteRecord.self,
        ])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeEngine(
        in container: ModelContainer,
        transport: MockSyncRemoteTransport? = nil,
        reachability: MockNetworkReachability? = nil
    ) -> (engine: SupabaseSyncEngine, transport: MockSyncRemoteTransport, reachability: MockNetworkReachability) {
        let resolvedTransport = transport ?? MockSyncRemoteTransport()
        let resolvedReachability = reachability ?? MockNetworkReachability(isOnline: true)
        let engine = SupabaseSyncEngine(
            modelContext: container.mainContext,
            transport: resolvedTransport,
            reachability: resolvedReachability
        )
        return (engine, resolvedTransport, resolvedReachability)
    }

    private func seedCompletedSession(
        in container: ModelContainer,
        planWorkoutId: UUID = UUID()
    ) throws -> WorkoutSessionRecord {
        let repo = SwiftDataWorkoutSessionRepository(modelContext: container.mainContext)
        let session = try repo.startOrResume(planWorkoutId: planWorkoutId, userId: UUID())
        _ = try repo.upsertSetLog(
            sessionId: session.id,
            id: nil,
            workoutExerciseId: UUID(),
            exerciseName: "Bench",
            setNumber: 1,
            reps: 8,
            weightKg: 60,
            durationSeconds: nil
        )
        try repo.complete(
            sessionId: session.id,
            endedAt: .now,
            durationSeconds: 1_200,
            notes: "Good"
        )
        return session
    }

    @Test("MockSyncEngine records enqueue and flush calls")
    func mockRecordsCalls() async {
        let engine = MockSyncEngine()
        engine.flushOnEnqueue = false
        let id = UUID()
        engine.enqueueSession(id: id)
        await engine.flushIfNeeded()
        #expect(engine.enqueueCalls == [id])
        #expect(engine.flushCallCount == 1)
    }

    @Test("Flush upserts pending sessions and set logs, then clears needsSync")
    func flushSucceedsAndClearsNeedsSync() async throws {
        let container = try makeContainer()
        let session = try seedCompletedSession(in: container)
        #expect(session.needsSync)
        #expect(session.setLogs.contains(where: { !$0.needsSync }) == false)

        let (engine, transport, _) = makeEngine(in: container)
        // Flush all needsSync rows (enqueue is only needed to wake opportunistic sync).
        await engine.flushIfNeeded()

        #expect(transport.sessionUpserts.count == 1)
        #expect(transport.sessionUpserts.first?.first?.id == session.id)
        #expect(transport.setLogUpserts.first?.count == 1)
        #expect(!session.needsSync)
        #expect(session.setLogs.contains(where: \.needsSync) == false)
    }

    @Test("Completed session flush updates plan_workouts status to completed")
    func completedSessionUpdatesPlanStatus() async throws {
        let container = try makeContainer()
        let planWorkoutId = UUID()
        let session = try seedCompletedSession(in: container, planWorkoutId: planWorkoutId)
        let (engine, transport, _) = makeEngine(in: container)

        // Call flush directly — avoid enqueue's fire-and-forget Task, which can
        // outlive the in-memory ModelContainer and crash the test host.
        await engine.flushIfNeeded()

        #expect(transport.planStatusCalls == [
            .init(id: planWorkoutId, status: WorkoutStatus.completed.rawValue)
        ])
        #expect(session.planWorkoutId == planWorkoutId)
    }

    @Test("Flush failure leaves needsSync set for retry")
    func flushFailureKeepsNeedsSync() async throws {
        let container = try makeContainer()
        let session = try seedCompletedSession(in: container)
        let transport = MockSyncRemoteTransport()
        transport.nextError = .networkUnavailable
        let (engine, _, _) = makeEngine(in: container, transport: transport)

        await engine.flushIfNeeded()

        #expect(session.needsSync)
        #expect(session.setLogs.contains(where: { !$0.needsSync }) == false)
        #expect(transport.sessionUpserts.isEmpty)
    }

    @Test("Offline flush is a no-op; going online can flush")
    func offlineSkipsUntilOnline() async throws {
        let container = try makeContainer()
        let session = try seedCompletedSession(in: container)
        let reachability = MockNetworkReachability(isOnline: false)
        let (engine, transport, _) = makeEngine(in: container, reachability: reachability)

        await engine.flushIfNeeded()
        #expect(transport.sessionUpserts.isEmpty)
        #expect(session.needsSync)

        // Flip online without firing the path-satisfied Task (avoids racing
        // the isFlushing guard); then flush explicitly.
        reachability.isOnline = true
        await engine.flushIfNeeded()
        #expect(transport.sessionUpserts.count == 1)
        #expect(!session.needsSync)
    }

    @Test("In-progress session flush does not update plan status")
    func inProgressDoesNotCompletePlan() async throws {
        let container = try makeContainer()
        let repo = SwiftDataWorkoutSessionRepository(modelContext: container.mainContext)
        let session = try repo.startOrResume(planWorkoutId: UUID(), userId: UUID())
        let (engine, transport, _) = makeEngine(in: container)

        await engine.flushIfNeeded()

        #expect(transport.sessionUpserts.count == 1)
        #expect(transport.planStatusCalls.isEmpty)
        #expect(!session.needsSync)
    }
}
