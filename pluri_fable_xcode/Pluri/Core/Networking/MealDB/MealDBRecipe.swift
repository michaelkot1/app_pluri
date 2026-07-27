import Foundation

/// One ingredient line on a MealDB recipe (name + measure).
struct MealDBIngredient: Hashable, Sendable, Codable {
    let name: String
    let measure: String
}

/// Domain model for a TheMealDB recipe.
///
/// `id` is the stable MealDB `idMeal` string and matches
/// `recipe_favorites.mealdb_recipe_id` / optional `food_logs.mealdb_recipe_id`.
/// Filter endpoints return summaries (name + thumb; optional area); lookup /
/// search fill instructions, ingredients, tags, and media when present.
/// `Codable` so day-suggestion / candidate caches can persist full recipes
/// offline (SPEC §14 #67g / M7-08).
struct MealDBRecipe: Identifiable, Hashable, Sendable, Codable {
    /// MealDB `idMeal` (e.g. `"52772"`).
    let id: String
    let name: String
    let thumbnailURL: URL?
    let category: String?
    /// Cuisine / region — MealDB `strArea` (SPEC §14 #67d/e).
    let area: String?
    let country: String?
    let instructions: String?
    let tags: [String]
    let youtubeURL: URL?
    let sourceURL: URL?
    let ingredients: [MealDBIngredient]
}
