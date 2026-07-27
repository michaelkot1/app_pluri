import Foundation
import os.log

/// Loads full MealDB recipes for the day-suggestions engine (M7-08).
///
/// Filter endpoints return summaries without ingredients — the engine needs
/// lookup/search-complete recipes for allergy + favorites similarity. Seeds
/// via `searchMeals` (full objects) plus Breakfast/Dessert category lookups.
nonisolated enum RecipeCandidateLoader {
    /// Search seeds that yield full recipes spanning protein / cuisine variety.
    static let searchSeeds = [
        "chicken", "beef", "pork", "salmon", "pasta", "salad",
        "soup", "cake", "pie", "egg", "rice", "bean", "tofu", "shrimp",
    ]

    /// Cap on unique full recipes kept in the pool (fair-use + memory).
    static let maxPoolSize = 48

    /// Max lookups after category filter for Breakfast / Dessert coverage.
    static let maxCategoryLookups = 12

    private static let logger = Logger(
        subsystem: "com.codewithmikey.pluri",
        category: "RecipeCandidateLoader"
    )

    /// Builds a full-recipe candidate pool from MealDB.
    static func loadPool(using client: any MealDBClient) async throws -> [MealDBRecipe] {
        var byID: [String: MealDBRecipe] = [:]

        for seed in searchSeeds {
            let matches = try await client.searchMeals(name: seed)
            for recipe in matches where !recipe.ingredients.isEmpty {
                byID[recipe.id] = recipe
                if byID.count >= maxPoolSize { break }
            }
            if byID.count >= maxPoolSize { break }
        }

        // Ensure Breakfast / Dessert slot pools have coverage (#69).
        try await enrichCategory(
            "Breakfast",
            into: &byID,
            using: client
        )
        try await enrichCategory(
            "Dessert",
            into: &byID,
            using: client
        )

        let pool = Array(byID.values).sorted { $0.id < $1.id }
        logger.info("Loaded candidate pool of \(pool.count, privacy: .public) recipes")
        return pool
    }

    private static func enrichCategory(
        _ category: String,
        into byID: inout [String: MealDBRecipe],
        using client: any MealDBClient
    ) async throws {
        let summaries = try await client.filterByCategory(category)
        var lookups = 0
        for summary in summaries {
            if byID[summary.id] != nil { continue }
            guard lookups < maxCategoryLookups else { break }
            guard byID.count < maxPoolSize else { break }
            do {
                let full = try await client.lookupMeal(id: summary.id)
                if !full.ingredients.isEmpty {
                    byID[full.id] = full
                }
                lookups += 1
            } catch {
                // Skip individual lookup failures; keep building the pool.
                continue
            }
        }
    }
}
