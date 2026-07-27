import Foundation

/// Fetches recipes from TheMealDB. Abstracted behind a protocol so a live
/// `URLSession`-backed implementation and a deterministic mock (for
/// previews/tests) can share call sites — see PLAN §3 / SPEC §12.
protocol MealDBClient: Sendable {
    /// Full-text search by meal name (`search.php?s=`).
    func searchMeals(name: String) async throws -> [MealDBRecipe]

    /// Full recipe by MealDB id (`lookup.php?i=`). Unknown id → `.notFound`.
    func lookupMeal(id: String) async throws -> MealDBRecipe

    /// Filter by cuisine / region (`filter.php?a=` → `strArea`).
    func filterByArea(_ area: String) async throws -> [MealDBRecipe]

    /// Filter by main ingredient (`filter.php?i=`).
    func filterByIngredient(_ ingredient: String) async throws -> [MealDBRecipe]

    /// Filter by category (`filter.php?c=`) — useful for Protein Explore
    /// values (Chicken, Beef, Pork, Seafood, Vegetarian, Vegan).
    func filterByCategory(_ category: String) async throws -> [MealDBRecipe]

    /// Cuisine / region labels (`list.php?a=list`).
    func listAreas() async throws -> [String]

    /// Ingredient labels (`list.php?i=list`).
    func listIngredients() async throws -> [String]

    /// Category labels (`list.php?c=list`).
    func listCategories() async throws -> [String]
}
