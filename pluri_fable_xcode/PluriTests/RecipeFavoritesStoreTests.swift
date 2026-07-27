import Foundation
import SwiftData
import Testing
@testable import Pluri

/// M7-07 — RecipeFavoritesStore + SyncEngine favorites flush.
@Suite("RecipeFavoritesStore")
@MainActor
struct RecipeFavoritesStoreTests {

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

    private func sampleRecipe(id: String = "52772") -> MealDBRecipe {
        MealDBRecipe(
            id: id,
            name: "Teriyaki Chicken Casserole",
            thumbnailURL: URL(string: "https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg"),
            category: "Chicken",
            area: "Japanese",
            country: "Japan",
            instructions: "Bake.",
            tags: [],
            youtubeURL: nil,
            sourceURL: nil,
            ingredients: [
                MealDBIngredient(name: "chicken breasts", measure: "2"),
                MealDBIngredient(name: "soy sauce", measure: "3/4 cup"),
            ]
        )
    }

    @Test("Toggle favorites locally and reads offline without network")
    func toggleLocalAndOfflineRead() throws {
        let container = try makeContainer()
        let userId = UUID()
        let sync = MockSyncEngine()
        sync.flushOnEnqueue = false
        let store = RecipeFavoritesStore(
            modelContext: container.mainContext,
            userId: userId,
            syncEngine: sync
        )
        let recipe = sampleRecipe()

        #expect(try store.isFavorite(id: recipe.id) == false)
        #expect(try store.toggle(recipe: recipe) == true)
        #expect(try store.isFavorite(id: recipe.id))
        let favorites = try store.allFavorites()
        #expect(favorites.count == 1)
        #expect(favorites.first?.mealdbRecipeId == recipe.id)
        #expect(favorites.first?.cachedTitle == recipe.name)
        #expect(sync.enqueueFavoriteCalls.count == 1)

        #expect(try store.toggle(recipe: recipe) == false)
        #expect(try store.isFavorite(id: recipe.id) == false)
        #expect(try store.allFavorites().isEmpty)
        // Unfavorite of never-synced row does not enqueue a remote delete.
        #expect(sync.enqueueFavoriteCalls.count == 1)
    }

    @Test("Flush upserts pending favorites and clears needsSync")
    func syncUpsertClearsNeedsSync() async throws {
        let container = try makeContainer()
        let userId = UUID()
        let transport = MockSyncRemoteTransport()
        let reachability = MockNetworkReachability(isOnline: true)
        let engine = SupabaseSyncEngine(
            modelContext: container.mainContext,
            transport: transport,
            reachability: reachability
        )
        let store = RecipeFavoritesStore(
            modelContext: container.mainContext,
            userId: userId,
            syncEngine: NoopSyncEngine()
        )
        let recipe = sampleRecipe()
        _ = try store.toggle(recipe: recipe)

        let record = try store.allFavorites().first
        #expect(record?.needsSync == true)

        await engine.flushIfNeeded()

        #expect(transport.recipeFavoriteUpserts.count == 1)
        #expect(transport.recipeFavoriteUpserts.first?.first?.mealdbRecipeId == recipe.id)
        #expect(record?.needsSync == false)
        #expect(transport.recipeFavoriteDeletes.isEmpty)
    }

    @Test("Unfavorite after sync enqueues remote delete and removes local row on flush")
    func syncDeleteOnUnfavorite() async throws {
        let container = try makeContainer()
        let userId = UUID()
        let transport = MockSyncRemoteTransport()
        let engine = SupabaseSyncEngine(
            modelContext: container.mainContext,
            transport: transport,
            reachability: MockNetworkReachability(isOnline: true)
        )
        let store = RecipeFavoritesStore(
            modelContext: container.mainContext,
            userId: userId,
            syncEngine: NoopSyncEngine()
        )
        let recipe = sampleRecipe()
        _ = try store.toggle(recipe: recipe)
        await engine.flushIfNeeded()
        #expect(try store.allFavorites().first?.needsSync == false)

        _ = try store.toggle(recipe: recipe)
        #expect(try store.isFavorite(id: recipe.id) == false)
        #expect(try store.allFavorites().isEmpty)

        // Pending delete row still exists until flush.
        let userIdCapture = userId
        let pending = try container.mainContext.fetch(
            FetchDescriptor<RecipeFavoriteRecord>(
                predicate: #Predicate { $0.userId == userIdCapture && $0.pendingDelete == true }
            )
        )
        #expect(pending.count == 1)
        #expect(pending.first?.needsSync == true)

        await engine.flushIfNeeded()
        #expect(transport.recipeFavoriteDeletes.count == 1)
        #expect(transport.recipeFavoriteDeletes.first?.first == pending.first?.id)
        let remaining = try container.mainContext.fetch(FetchDescriptor<RecipeFavoriteRecord>())
        #expect(remaining.isEmpty)
    }

    @Test("Flush failure leaves favorite needsSync set for retry")
    func syncFailureKeepsNeedsSync() async throws {
        let container = try makeContainer()
        let transport = MockSyncRemoteTransport()
        transport.nextError = .networkUnavailable
        let engine = SupabaseSyncEngine(
            modelContext: container.mainContext,
            transport: transport,
            reachability: MockNetworkReachability(isOnline: true)
        )
        let store = RecipeFavoritesStore(
            modelContext: container.mainContext,
            userId: UUID(),
            syncEngine: NoopSyncEngine()
        )
        _ = try store.toggle(recipe: sampleRecipe())
        let record = try store.allFavorites().first

        await engine.flushIfNeeded()

        #expect(record?.needsSync == true)
        #expect(transport.recipeFavoriteUpserts.isEmpty)
    }
}
