import Foundation
import SwiftData

/// Local SwiftData cache for a nutrition food log (M7-11 / SPEC §14 #67f).
///
/// Aligns with Postgres `food_logs` plus local sync bookkeeping
/// (`needsSync`, `pendingDelete`) so saves stay offline-first.
/// Calories are always known on insert — nil-kcal Nutrition hits are not
/// persistable (SPEC §14 #68 interim).
@Model
final class FoodLogRecord {
    var id: UUID = UUID()
    var userId: UUID = UUID()
    var foodName: String = ""
    /// Serving label (e.g. user query `"1 cup rice"`) — Nutrition README.
    var serving: String = ""
    /// Kilocalories for the chosen serving — required (≥ 0).
    var calories: Int = 0
    /// Optional JSON blob matching remote `macros` jsonb.
    var macrosJSON: Data?
    /// `FoodLogMeal` raw value (`breakfast`…`snack`).
    var meal: String = FoodLogMeal.snack.rawValue
    /// Calendar day of the log (start-of-day), matches `logged_date`.
    var loggedDate: Date = Date()
    var mealdbRecipeId: String?
    var nutritionFoodId: String?
    var createdAt: Date = Date()
    /// Cleared after a successful SyncEngine food-log flush.
    var needsSync: Bool = true
    /// Offline delete of a previously synced row — remote delete on flush,
    /// then local delete.
    var pendingDelete: Bool = false

    init(
        id: UUID = UUID(),
        userId: UUID,
        foodName: String,
        serving: String,
        calories: Int,
        macrosJSON: Data? = nil,
        meal: FoodLogMeal,
        loggedDate: Date,
        mealdbRecipeId: String? = nil,
        nutritionFoodId: String? = nil,
        createdAt: Date = .now,
        needsSync: Bool = true,
        pendingDelete: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.foodName = foodName
        self.serving = serving
        self.calories = calories
        self.macrosJSON = macrosJSON
        self.meal = meal.rawValue
        self.loggedDate = loggedDate
        self.mealdbRecipeId = mealdbRecipeId
        self.nutritionFoodId = nutritionFoodId
        self.createdAt = createdAt
        self.needsSync = needsSync
        self.pendingDelete = pendingDelete
    }

    var mealTag: FoodLogMeal {
        FoodLogMeal(rawValue: meal) ?? .snack
    }
}
