import Foundation

/// Domain model for one food hit from the Nutrition API (API Ninjas).
///
/// The free tier gates `calories` and `protein_g` behind premium — those
/// properties are optional so Log UI can stay honest (see README / SPEC §14 #68).
struct NutritionFood: Identifiable, Hashable, Sendable {
    /// Synthetic stable-ish id for list identity (`name|serving_g`). The API
    /// does not return a durable food id; `food_logs.nutrition_food_id` may
    /// store this or a future premium id.
    let id: String
    let name: String
    /// Serving size in grams as returned by the API for the query.
    let servingSizeGrams: Double
    /// Kilocalories for the serving — `nil` when premium-gated on free tier.
    let calories: Double?
    /// Protein grams — `nil` when premium-gated on free tier.
    let proteinGrams: Double?
    let fatTotalGrams: Double?
    let fatSaturatedGrams: Double?
    let carbohydratesTotalGrams: Double?
    let fiberGrams: Double?
    let sugarGrams: Double?
    let sodiumMilligrams: Double?
    let potassiumMilligrams: Double?
    let cholesterolMilligrams: Double?
}
