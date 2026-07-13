import Foundation
import SwiftData
import os.log

/// Serves the exercise catalog from SwiftData, refreshing from
/// `WorkoutXClient` only when the cache is stale (M1-03).
///
/// Decision: a **7-day** staleness window. WorkoutX's free-tier quota is
/// 500 requests/month (see `Core/Networking/WorkoutX/README.md`) and the
/// catalog itself rarely changes, so refreshing on every launch would waste
/// quota for no user-visible benefit; a week keeps the cache reasonably
/// fresh without meaningfully risking staleness for a weight-training
/// exercise database.
@MainActor
@Observable
final class ExerciseCatalogStore {
    enum RefreshStatus: Equatable {
        case idle
        case refreshing
        case failed(String)
    }

    nonisolated static let stalenessWindow: TimeInterval = 60 * 60 * 24 * 7

    private(set) var refreshStatus: RefreshStatus = .idle

    private let modelContext: ModelContext
    private let client: WorkoutXClient
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "ExerciseCatalogStore")

    init(modelContext: ModelContext, client: WorkoutXClient) {
        self.modelContext = modelContext
        self.client = client
    }

    /// Pure staleness check, exposed as a static function so it's testable
    /// without a `ModelContext` (no test target exists yet — see M1-03 report).
    nonisolated static func isStale(lastSyncedAt: Date?, now: Date = .now, stalenessWindow: TimeInterval = stalenessWindow) -> Bool {
        guard let lastSyncedAt else { return true }
        return now.timeIntervalSince(lastSyncedAt) > stalenessWindow
    }

    /// All cached exercises, in whatever order SwiftData returns them.
    func cachedExercises() throws -> [Exercise] {
        try modelContext.fetch(FetchDescriptor<CachedExercise>()).map(\.asDomainExercise)
    }

    /// Refreshes from `WorkoutXClient` only if the cache is empty or stale.
    func refreshIfNeeded() async {
        let state = try? fetchSyncState()
        let isEmpty = (try? modelContext.fetchCount(FetchDescriptor<CachedExercise>())) == 0
        guard isEmpty || Self.isStale(lastSyncedAt: state?.lastSyncedAt) else { return }
        await refresh()
    }

    /// Unconditionally refreshes the cache from `WorkoutXClient`.
    func refresh() async {
        refreshStatus = .refreshing
        do {
            let exercises = try await client.fetchFullCatalog()
            try upsert(exercises)
            try setLastSyncedAt(.now)
            refreshStatus = .idle
            logger.info("Refreshed exercise catalog: \(exercises.count) exercises")
        } catch {
            refreshStatus = .failed(error.localizedDescription)
            logger.error("Exercise catalog refresh failed: \(error.localizedDescription)")
        }
    }

    private func fetchSyncState() throws -> ExerciseCatalogSyncState? {
        try modelContext.fetch(FetchDescriptor<ExerciseCatalogSyncState>()).first
    }

    private func setLastSyncedAt(_ date: Date) throws {
        if let state = try fetchSyncState() {
            state.lastSyncedAt = date
        } else {
            modelContext.insert(ExerciseCatalogSyncState(lastSyncedAt: date))
        }
        try modelContext.save()
    }

    private func upsert(_ exercises: [Exercise]) throws {
        var existingByID = Dictionary(
            uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<CachedExercise>()).map { ($0.id, $0) }
        )
        for exercise in exercises {
            if let cached = existingByID.removeValue(forKey: exercise.id) {
                cached.update(with: exercise)
            } else {
                modelContext.insert(CachedExercise(exercise: exercise))
            }
        }
        // Anything left in `existingByID` no longer exists upstream.
        for stale in existingByID.values {
            modelContext.delete(stale)
        }
        try modelContext.save()
    }
}
