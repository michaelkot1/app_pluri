import Foundation
import SwiftData
import os.log

/// Offline-first favorites store for MealDB recipes (M7-07 / SPEC §14 #67f/g).
///
/// Toggle / read always hit SwiftData first and never block on network.
/// Opportunistic sync to `recipe_favorites` goes through `SyncEngine`.
@MainActor
@Observable
final class RecipeFavoritesStore {
    private let modelContext: ModelContext
    private let userId: UUID
    private let syncEngine: any SyncEngine
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "RecipeFavorites")

    init(
        modelContext: ModelContext,
        userId: UUID,
        syncEngine: (any SyncEngine)? = nil
    ) {
        self.modelContext = modelContext
        self.userId = userId
        self.syncEngine = syncEngine ?? NoopSyncEngine()
    }

    /// Favorites visible offline (excludes pending deletes).
    func allFavorites() throws -> [RecipeFavoriteRecord] {
        let userId = self.userId
        let descriptor = FetchDescriptor<RecipeFavoriteRecord>(
            predicate: #Predicate { record in
                record.userId == userId && record.pendingDelete == false
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// `true` when the recipe is favorited and not pending delete.
    func isFavorite(id mealdbRecipeId: String) throws -> Bool {
        try activeRecord(mealdbRecipeId: mealdbRecipeId) != nil
    }

    /// Toggles favorite locally and enqueues opportunistic sync.
    ///
    /// Returns the new favorite state (`true` = favorited).
    @discardableResult
    func toggle(recipe: MealDBRecipe) throws -> Bool {
        if let existing = try anyRecord(mealdbRecipeId: recipe.id) {
            if existing.pendingDelete {
                // Re-favorite while a remote delete was still pending.
                existing.pendingDelete = false
                existing.cachedTitle = recipe.name
                existing.cachedThumbURL = recipe.thumbnailURL?.absoluteString
                existing.needsSync = true
                try modelContext.save()
                syncEngine.enqueueFavorite(id: existing.id)
                return true
            }

            // Unfavorite.
            if existing.needsSync {
                // Never successfully flushed — drop local only (no remote row).
                modelContext.delete(existing)
                try modelContext.save()
                return false
            }

            existing.pendingDelete = true
            existing.needsSync = true
            try modelContext.save()
            syncEngine.enqueueFavorite(id: existing.id)
            return false
        }

        let record = RecipeFavoriteRecord(
            userId: userId,
            mealdbRecipeId: recipe.id,
            cachedTitle: recipe.name,
            cachedThumbURL: recipe.thumbnailURL?.absoluteString,
            needsSync: true,
            pendingDelete: false
        )
        modelContext.insert(record)
        try modelContext.save()
        syncEngine.enqueueFavorite(id: record.id)
        logger.info("Favorited meal \(recipe.id, privacy: .public)")
        return true
    }

    // MARK: - Private

    private func activeRecord(mealdbRecipeId: String) throws -> RecipeFavoriteRecord? {
        let userId = self.userId
        var descriptor = FetchDescriptor<RecipeFavoriteRecord>(
            predicate: #Predicate { record in
                record.userId == userId
                    && record.mealdbRecipeId == mealdbRecipeId
                    && record.pendingDelete == false
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func anyRecord(mealdbRecipeId: String) throws -> RecipeFavoriteRecord? {
        let userId = self.userId
        var descriptor = FetchDescriptor<RecipeFavoriteRecord>(
            predicate: #Predicate { record in
                record.userId == userId && record.mealdbRecipeId == mealdbRecipeId
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
