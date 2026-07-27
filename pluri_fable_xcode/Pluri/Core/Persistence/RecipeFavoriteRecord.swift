import Foundation
import SwiftData

/// Local SwiftData cache for a favorited MealDB recipe (M7-07 / SPEC §14 #67f).
///
/// Aligns with Postgres `recipe_favorites` plus local sync bookkeeping
/// (`needsSync`, `pendingDelete`) so toggles stay offline-first.
@Model
final class RecipeFavoriteRecord {
    /// Composite uniqueness mirrors Postgres `UNIQUE (user_id, mealdb_recipe_id)`.
    /// `id` remains the LWW sync primary key without a second `#Unique` (SwiftData
    /// allows only one `#Unique` per model).
    #Unique<RecipeFavoriteRecord>([\.userId, \.mealdbRecipeId])

    var id: UUID = UUID()
    var userId: UUID = UUID()
    /// MealDB `idMeal` — matches `recipe_favorites.mealdb_recipe_id`.
    var mealdbRecipeId: String = ""
    var cachedTitle: String?
    var cachedThumbURL: String?
    var createdAt: Date = Date()
    /// Cleared after a successful SyncEngine favorites flush.
    var needsSync: Bool = true
    /// Offline unfavorite of a previously synced row — remote delete on flush,
    /// then local delete.
    var pendingDelete: Bool = false

    init(
        id: UUID = UUID(),
        userId: UUID,
        mealdbRecipeId: String,
        cachedTitle: String? = nil,
        cachedThumbURL: String? = nil,
        createdAt: Date = .now,
        needsSync: Bool = true,
        pendingDelete: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.mealdbRecipeId = mealdbRecipeId
        self.cachedTitle = cachedTitle
        self.cachedThumbURL = cachedThumbURL
        self.createdAt = createdAt
        self.needsSync = needsSync
        self.pendingDelete = pendingDelete
    }
}
