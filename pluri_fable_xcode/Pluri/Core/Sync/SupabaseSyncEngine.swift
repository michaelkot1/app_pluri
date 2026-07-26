import Foundation
import SwiftData
import os.log

/// SwiftData → Supabase SyncEngine (M4-03): uploads pending sessions and set
/// logs (LWW upsert by id), and marks linked plan workouts completed when a
/// flushed session has `endedAt` + `planWorkoutId` (SPEC §14 #52).
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

    func flushIfNeeded() async {
        guard reachability.isOnline else { return }
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        do {
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
        } catch {
            logger.error("Sync flush failed: \(error.localizedDescription, privacy: .public)")
            // Leave needsSync set — retry on next online / flushIfNeeded.
        }
    }

    // MARK: - Private

    private func pendingSessions() throws -> [WorkoutSessionRecord] {
        let descriptor = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { session in
                session.needsSync == true
            }
        )
        var pending = try modelContext.fetch(descriptor)

        // Also pull explicitly enqueued sessions that may already be marked synced
        // but need a re-flush (defensive — enqueue normally races with mutate).
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
}
