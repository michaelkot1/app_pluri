import Foundation

/// Wire-format food row from API Ninjas `GET /nutrition`.
///
/// Free-tier responses may return the string
/// `"Only available for premium subscribers."` for `calories` and
/// `protein_g` instead of a number — decoded as `nil` on the domain model.
struct NutritionFoodDTO: Decodable, Sendable {
    let name: String
    let servingSizeG: Double
    let calories: FlexibleNutritionNumber
    let proteinG: FlexibleNutritionNumber
    let fatTotalG: FlexibleNutritionNumber
    let fatSaturatedG: FlexibleNutritionNumber
    let carbohydratesTotalG: FlexibleNutritionNumber
    let fiberG: FlexibleNutritionNumber
    let sugarG: FlexibleNutritionNumber
    let sodiumMg: FlexibleNutritionNumber
    let potassiumMg: FlexibleNutritionNumber
    let cholesterolMg: FlexibleNutritionNumber

    enum CodingKeys: String, CodingKey {
        case name
        case servingSizeG = "serving_size_g"
        case calories
        case proteinG = "protein_g"
        case fatTotalG = "fat_total_g"
        case fatSaturatedG = "fat_saturated_g"
        case carbohydratesTotalG = "carbohydrates_total_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case sodiumMg = "sodium_mg"
        case potassiumMg = "potassium_mg"
        case cholesterolMg = "cholesterol_mg"
    }

    var asDomainFood: NutritionFood {
        let serving = servingSizeG
        // Locale-independent id (not for display) — FormatStyle would vary by locale.
        let servingKey = String(serving)
        return NutritionFood(
            id: "\(name.lowercased())|\(servingKey)",
            name: name,
            servingSizeGrams: serving,
            calories: calories.value,
            proteinGrams: proteinG.value,
            fatTotalGrams: fatTotalG.value,
            fatSaturatedGrams: fatSaturatedG.value,
            carbohydratesTotalGrams: carbohydratesTotalG.value,
            fiberGrams: fiberG.value,
            sugarGrams: sugarG.value,
            sodiumMilligrams: sodiumMg.value,
            potassiumMilligrams: potassiumMg.value,
            cholesterolMilligrams: cholesterolMg.value
        )
    }
}

/// Decodes a JSON number **or** a non-numeric premium-gate string as `nil`.
struct FlexibleNutritionNumber: Decodable, Sendable {
    let value: Double?

    init(value: Double?) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
            return
        }
        if let double = try? container.decode(Double.self) {
            value = double
            return
        }
        if let int = try? container.decode(Int.self) {
            value = Double(int)
            return
        }
        if let string = try? container.decode(String.self) {
            value = Double(string)
            return
        }
        value = nil
    }
}
