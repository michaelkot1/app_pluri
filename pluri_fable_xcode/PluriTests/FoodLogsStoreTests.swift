import Foundation
import SwiftData
import Testing
@testable import Pluri

/// M7-11 — FoodLogsStore insert, day totals, sync flags.
@Suite("FoodLogsStore")
@MainActor
struct FoodLogsStoreTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema([FoodLogRecord.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Insert updates day calorie total and sets needsSync")
    func insertDayTotalAndSyncFlag() throws {
        let container = try makeContainer()
        let sync = MockSyncEngine()
        sync.flushOnEnqueue = false
        let userId = UUID()
        let store = FoodLogsStore(
            modelContext: container.mainContext,
            userId: userId,
            syncEngine: sync
        )
        let day = Calendar.current.startOfDay(for: .now)

        let first = try store.insert(
            foodName: "apple",
            serving: "1 apple",
            calories: 95,
            meal: .snack,
            loggedDate: day
        )
        #expect(first.needsSync)
        #expect(try store.dayCalorieTotal(on: day) == 95)
        #expect(sync.enqueueFoodLogCalls.count == 1)

        _ = try store.insert(
            foodName: "chicken breast",
            serving: "100g chicken breast",
            calories: 165,
            meal: .lunch,
            loggedDate: day
        )
        #expect(try store.dayCalorieTotal(on: day) == 260)
        #expect(sync.enqueueFoodLogCalls.count == 2)

        let progress = try store.dayCalorieProgress(on: day, maintenanceCalories: 2_000)
        #expect(progress.eatenCalories == 260)
        #expect(progress.maintenanceCalories == 2_000)
        #expect(abs(progress.fraction - 0.13) < 0.0001)
    }

    @Test("Offline insert still persists locally and enqueues sync")
    func offlineInsertDoesNotBlock() throws {
        let container = try makeContainer()
        let sync = MockSyncEngine()
        sync.isOnline = false
        sync.flushOnEnqueue = false
        let store = FoodLogsStore(
            modelContext: container.mainContext,
            userId: UUID(),
            syncEngine: sync
        )
        let day = Calendar.current.startOfDay(for: .now)
        let record = try store.insert(
            foodName: "apple",
            serving: "1 apple",
            calories: 95,
            meal: .breakfast,
            loggedDate: day
        )
        #expect(record.needsSync)
        #expect(try store.logs(on: day).count == 1)
        #expect(sync.enqueueFoodLogCalls.count == 1)
    }

    @Test("Flush upserts pending food logs and clears needsSync")
    func syncUpsertClearsNeedsSync() async throws {
        let container = try makeContainer()
        let userId = UUID()
        let transport = MockSyncRemoteTransport()
        let engine = SupabaseSyncEngine(
            modelContext: container.mainContext,
            transport: transport,
            reachability: MockNetworkReachability(isOnline: true)
        )
        let store = FoodLogsStore(
            modelContext: container.mainContext,
            userId: userId,
            syncEngine: NoopSyncEngine()
        )
        let record = try store.insert(
            foodName: "apple",
            serving: "1 apple",
            calories: 95,
            meal: .snack,
            loggedDate: .now
        )
        #expect(record.needsSync)

        await engine.flushIfNeeded()

        #expect(transport.foodLogUpserts.count == 1)
        #expect(transport.foodLogUpserts.first?.first?.foodName == "apple")
        #expect(transport.foodLogUpserts.first?.first?.calories == 95)
        #expect(record.needsSync == false)
    }

    @Test("Day total vs maintenance math caps at 1")
    func progressCapsAtOne() {
        let over = DayCalorieProgress(eatenCalories: 3_000, maintenanceCalories: 2_000)
        #expect(over.fraction == 1)
        let none = DayCalorieProgress(eatenCalories: 400, maintenanceCalories: nil)
        #expect(none.fraction == 0)
        #expect(none.hasMaintenanceTarget == false)
    }

    @Test("Flush of manually flagged pendingDelete deletes remotely and locally")
    func syncPendingDeleteFlush() async throws {
        // No FoodLogsStore delete API / UI yet (M7-13) — exercise SyncEngine
        // flush path with a row flagged like favorites' pendingDelete.
        let container = try makeContainer()
        let transport = MockSyncRemoteTransport()
        let engine = SupabaseSyncEngine(
            modelContext: container.mainContext,
            transport: transport,
            reachability: MockNetworkReachability(isOnline: true)
        )
        let record = FoodLogRecord(
            userId: UUID(),
            foodName: "apple",
            serving: "1 apple",
            calories: 95,
            meal: .snack,
            loggedDate: Calendar.current.startOfDay(for: .now),
            needsSync: true,
            pendingDelete: true
        )
        container.mainContext.insert(record)
        try container.mainContext.save()

        await engine.flushIfNeeded()

        #expect(transport.foodLogDeletes.count == 1)
        #expect(transport.foodLogDeletes.first?.first == record.id)
        #expect(transport.foodLogUpserts.isEmpty)
        let remaining = try container.mainContext.fetch(FetchDescriptor<FoodLogRecord>())
        #expect(remaining.isEmpty)
    }
}
