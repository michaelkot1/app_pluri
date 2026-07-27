import Foundation

/// Macro payload for `food_logs.macros` jsonb (M7-11).
///
/// Mirrors the Nutrition domain fields we persist when known. Nil-calorie
/// hits are never saved, but other macros may still be absent on free tier.
nonisolated struct FoodLogMacrosJSON: Codable, Hashable, Sendable, Equatable {
    var proteinGrams: Double?
    var fatTotalGrams: Double?
    var fatSaturatedGrams: Double?
    var carbohydratesTotalGrams: Double?
    var fiberGrams: Double?
    var sugarGrams: Double?
    var sodiumMilligrams: Double?
    var potassiumMilligrams: Double?
    var cholesterolMilligrams: Double?

    enum CodingKeys: String, CodingKey {
        case proteinGrams = "protein_g"
        case fatTotalGrams = "fat_total_g"
        case fatSaturatedGrams = "fat_saturated_g"
        case carbohydratesTotalGrams = "carbohydrates_total_g"
        case fiberGrams = "fiber_g"
        case sugarGrams = "sugar_g"
        case sodiumMilligrams = "sodium_mg"
        case potassiumMilligrams = "potassium_mg"
        case cholesterolMilligrams = "cholesterol_mg"
    }

    init(from food: NutritionFood) {
        proteinGrams = food.proteinGrams
        fatTotalGrams = food.fatTotalGrams
        fatSaturatedGrams = food.fatSaturatedGrams
        carbohydratesTotalGrams = food.carbohydratesTotalGrams
        fiberGrams = food.fiberGrams
        sugarGrams = food.sugarGrams
        sodiumMilligrams = food.sodiumMilligrams
        potassiumMilligrams = food.potassiumMilligrams
        cholesterolMilligrams = food.cholesterolMilligrams
    }

    func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(from data: Data?) -> FoodLogMacrosJSON? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(FoodLogMacrosJSON.self, from: data)
    }
}
