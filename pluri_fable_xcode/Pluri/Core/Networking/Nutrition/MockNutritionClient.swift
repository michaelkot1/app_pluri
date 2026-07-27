import Foundation

/// Deterministic in-memory `NutritionClient` for previews and tests — no
/// network access, no quota usage.
struct MockNutritionClient: NutritionClient {
    let fixtures: [NutritionFood]
    var errorToThrow: NutritionClientError?

    init(
        fixtures: [NutritionFood] = .nutritionPreviewFixtures,
        errorToThrow: NutritionClientError? = nil
    ) {
        self.fixtures = fixtures
        self.errorToThrow = errorToThrow
    }

    func searchFoods(query: String) async throws -> [NutritionFood] {
        if let errorToThrow {
            throw errorToThrow
        }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        return fixtures.filter { $0.name.localizedStandardContains(needle) }
    }
}

extension [NutritionFood] {
    /// Deterministic fixtures spanning free-tier-complete macros and a
    /// premium-gated calories/protein example for Log honesty tests.
    static var nutritionPreviewFixtures: [NutritionFood] {
        [
            NutritionFood(
                id: "apple|182",
                name: "apple",
                servingSizeGrams: 182,
                calories: 95,
                proteinGrams: 0.5,
                fatTotalGrams: 0.3,
                fatSaturatedGrams: 0.1,
                carbohydratesTotalGrams: 25.6,
                fiberGrams: 4.3,
                sugarGrams: 18.8,
                sodiumMilligrams: 1,
                potassiumMilligrams: 20,
                cholesterolMilligrams: 0
            ),
            NutritionFood(
                id: "chicken breast|100",
                name: "chicken breast",
                servingSizeGrams: 100,
                calories: 165,
                proteinGrams: 31,
                fatTotalGrams: 3.5,
                fatSaturatedGrams: 1.0,
                carbohydratesTotalGrams: 0,
                fiberGrams: 0,
                sugarGrams: 0,
                sodiumMilligrams: 72,
                potassiumMilligrams: 226,
                cholesterolMilligrams: 85
            ),
            NutritionFood(
                id: "brisket|453.592",
                name: "brisket",
                servingSizeGrams: 453.592,
                // Mirrors free-tier gate: fat/carbs present, calories/protein nil.
                calories: nil,
                proteinGrams: nil,
                fatTotalGrams: 82.9,
                fatSaturatedGrams: 33.2,
                carbohydratesTotalGrams: 0,
                fiberGrams: 0,
                sugarGrams: 0,
                sodiumMilligrams: 217,
                potassiumMilligrams: 781,
                cholesterolMilligrams: 487
            ),
        ]
    }
}
