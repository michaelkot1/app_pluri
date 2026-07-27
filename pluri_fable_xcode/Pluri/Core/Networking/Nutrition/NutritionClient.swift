import Foundation

/// Looks up nutrition facts for a free-text food query. Abstracted behind a
/// protocol so a live `URLSession`-backed implementation and a deterministic
/// mock (for previews/tests) can share call sites — see PLAN §3 / SPEC §12.
protocol NutritionClient: Sendable {
    /// Query the Nutrition API (e.g. `"1 apple"`, `"100g chicken breast"`).
    /// Returns zero or more foods for the serving implied by the query.
    func searchFoods(query: String) async throws -> [NutritionFood]
}
