import Foundation
import SwiftData
import os.log

/// SwiftData → Supabase SyncEngine (M4-03 + M7-07 + M7-11): uploads pending
/// sessions, set logs, recipe favorites, and food logs (LWW upsert by id), and
/// marks linked plan workouts completed when a flushed session has `endedAt` +
/// `planWorkoutId` (SPEC §14 #52). Favorites / food logs support pending remote
/// deletes (SPEC §14 #67f).
///
/// Never blocks the repository. Failures leave `needsSync` set for retry.
@MainActor
@Observable
final class SupabaseSyncEngine: SyncEngine {
    private let modelContext: ModelContext
    private let transport: any SyncRemoteTransporting
    private let reachability: any NetworkReachability
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "SyncEngine")

    private var isFlushing = false
    private var pendingEnqueueIDs: Set<UUID> = []
    private var pendingFavoriteEnqueueIDs: Set<UUID> = []
    private var pendingFoodLogEnqueueIDs: Set<UUID> = []

    init(
        modelContext: ModelContext,
        transport: any SyncRemoteTransporting,
        reachability: (any NetworkReachability)? = nil
    ) {
        self.modelContext = modelContext
        self.transport = transport
        self.reachability = reachability ?? PathMonitorReachability()
        self.reachability.onPathSatisfied = { [weak self] in
            Task { await self?.flushIfNeeded() }
        }
        self.reachability.start()
    }

    convenience init(modelContext: ModelContext, supabaseService: SupabaseService) {
        self.init(
            modelContext: modelContext,
            transport: SupabaseSyncRemoteTransport(supabaseService: supabaseService),
            reachability: PathMonitorReachability()
        )
    }

    func enqueueSession(id: UUID) {
        pendingEnqueueIDs.insert(id)
        Task { await flushIfNeeded() }
    }

    func enqueueFavorite(id: UUID) {
        pendingFavoriteEnqueueIDs.insert(id)
        Task { await flushIfNeeded() }
    }

    func enqueueFoodLog(id: UUID) {
        pendingFoodLogEnqueueIDs.insert(id)
        Task { await flushIfNeeded() }
    }

    func flushIfNeeded() async {
        guard reachability.isOnline else { return }
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        do {
            try await flushSessions()
            try await flushFavorites()
            try await flushFoodLogs()
        } catch {
            logger.error("Sync flush failed: \(error.localizedDescription, privacy: .public)")
            // Leave needsSync set — retry on next online / flushIfNeeded.
        }
    }

    // MARK: - Sessions

    private func flushSessions() async throws {
        let sessions = try pendingSessions()
        guard !sessions.isEmpty else {
            pendingEnqueueIDs.removeAll()
            return
        }

        let sessionRows = sessions.map(OnboardingSyncMapper.sessionRow(for:))
        try await transport.upsertSessions(sessionRows)

        var setRows: [SetLogUpsertRow] = []
        for session in sessions {
            for setLog in session.setLogs where setLog.needsSync {
                setRows.append(OnboardingSyncMapper.setLogRow(for: setLog, sessionId: session.id))
            }
        }
        try await transport.upsertSetLogs(setRows)

        for session in sessions where session.endedAt != nil {
            if let planWorkoutId = session.planWorkoutId {
                try await transport.updatePlanWorkoutStatus(
                    id: planWorkoutId,
                    status: WorkoutStatus.completed.rawValue
                )
            }
        }

        for session in sessions {
            session.needsSync = false
            for setLog in session.setLogs where setLog.needsSync {
                setLog.needsSync = false
            }
            pendingEnqueueIDs.remove(session.id)
        }
        try modelContext.save()
        logger.info("Flushed \(sessions.count, privacy: .public) workout session(s)")
    }

    private func pendingSessions() throws -> [WorkoutSessionRecord] {
        let descriptor = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { session in
                session.needsSync == true
            }
        )
        var pending = try modelContext.fetch(descriptor)

        for id in pendingEnqueueIDs {
            if pending.contains(where: { $0.id == id }) { continue }
            var byID = FetchDescriptor<WorkoutSessionRecord>(
                predicate: #Predicate { session in
                    session.id == id
                }
            )
            byID.fetchLimit = 1
            if let session = try modelContext.fetch(byID).first {
                pending.append(session)
            }
        }
        return pending
    }

    // MARK: - Favorites (M7-07)

    private func flushFavorites() async throws {
        let favorites = try pendingFavorites()
        guard !favorites.isEmpty else {
            pendingFavoriteEnqueueIDs.removeAll()
            return
        }

        let toUpsert = favorites.filter { !$0.pendingDelete }
        let toDelete = favorites.filter(\.pendingDelete)

        if !toUpsert.isEmpty {
            let rows = toUpsert.map(OnboardingSyncMapper.recipeFavoriteRow(for:))
            try await transport.upsertRecipeFavorites(rows)
            for record in toUpsert {
                record.needsSync = false
                pendingFavoriteEnqueueIDs.remove(record.id)
            }
        }

        if !toDelete.isEmpty {
            try await transport.deleteRecipeFavorites(ids: toDelete.map(\.id))
            for record in toDelete {
                pendingFavoriteEnqueueIDs.remove(record.id)
                modelContext.delete(record)
            }
        }

        try modelContext.save()
        logger.info(
            "Flushed \(toUpsert.count, privacy: .public) favorite upsert(s), \(toDelete.count, privacy: .public) delete(s)"
        )
    }

    private func pendingFavorites() throws -> [RecipeFavoriteRecord] {
        let descriptor = FetchDescriptor<RecipeFavoriteRecord>(
            predicate: #Predicate { record in
                record.needsSync == true
            }
        )
        var pending = try modelContext.fetch(descriptor)

        for id in pendingFavoriteEnqueueIDs {
            if pending.contains(where: { $0.id == id }) { continue }
            var byID = FetchDescriptor<RecipeFavoriteRecord>(
                predicate: #Predicate { record in
                    record.id == id
                }
            )
            byID.fetchLimit = 1
            if let record = try modelContext.fetch(byID).first {
                pending.append(record)
            }
        }
        return pending
    }

    // MARK: - Food logs (M7-11)

    private func flushFoodLogs() async throws {
        let logs = try pendingFoodLogs()
        guard !logs.isEmpty else {
            pendingFoodLogEnqueueIDs.removeAll()
            return
        }

        let toUpsert = logs.filter { !$0.pendingDelete }
        let toDelete = logs.filter(\.pendingDelete)

        if !toUpsert.isEmpty {
            let rows = toUpsert.map(OnboardingSyncMapper.foodLogRow(for:))
            try await transport.upsertFoodLogs(rows)
            for record in toUpsert {
                record.needsSync = false
                pendingFoodLogEnqueueIDs.remove(record.id)
            }
        }

        if !toDelete.isEmpty {
            try await transport.deleteFoodLogs(ids: toDelete.map(\.id))
            for record in toDelete {
                pendingFoodLogEnqueueIDs.remove(record.id)
                modelContext.delete(record)
            }
        }

        try modelContext.save()
        logger.info(
            "Flushed \(toUpsert.count, privacy: .public) food-log upsert(s), \(toDelete.count, privacy: .public) delete(s)"
        )
    }

    private func pendingFoodLogs() throws -> [FoodLogRecord] {
        let descriptor = FetchDescriptor<FoodLogRecord>(
            predicate: #Predicate { record in
                record.needsSync == true
            }
        )
        var pending = try modelContext.fetch(descriptor)

        for id in pendingFoodLogEnqueueIDs {
            if pending.contains(where: { $0.id == id }) { continue }
            var byID = FetchDescriptor<FoodLogRecord>(
                predicate: #Predicate { record in
                    record.id == id
                }
            )
            byID.fetchLimit = 1
            if let record = try modelContext.fetch(byID).first {
                pending.append(record)
            }
        }
        return pending
    }
}
