import Foundation

/// Wire envelope for MealDB list/search/filter/lookup responses.
///
/// Empty results arrive as `"meals": null` (not `[]`) — decode as optional.
struct MealDBMealsEnvelope: Decodable, Sendable {
    let meals: [MealDBMealDTO]?
}

/// Wire-format meal row from TheMealDB.
///
/// Lookup/search return the full object (ingredients 1…20, instructions, etc.).
/// Filter returns a summary (`idMeal`, `strMeal`, `strMealThumb`, and sometimes
/// `strArea` / `strCountry`). Only fields Pluri uses are mapped to domain.
struct MealDBMealDTO: Decodable, Sendable {
    let idMeal: String
    let strMeal: String
    let strMealThumb: String?
    let strCategory: String?
    let strArea: String?
    let strCountry: String?
    let strInstructions: String?
    let strTags: String?
    let strYoutube: String?
    let strSource: String?

    let strIngredient1: String?
    let strIngredient2: String?
    let strIngredient3: String?
    let strIngredient4: String?
    let strIngredient5: String?
    let strIngredient6: String?
    let strIngredient7: String?
    let strIngredient8: String?
    let strIngredient9: String?
    let strIngredient10: String?
    let strIngredient11: String?
    let strIngredient12: String?
    let strIngredient13: String?
    let strIngredient14: String?
    let strIngredient15: String?
    let strIngredient16: String?
    let strIngredient17: String?
    let strIngredient18: String?
    let strIngredient19: String?
    let strIngredient20: String?

    let strMeasure1: String?
    let strMeasure2: String?
    let strMeasure3: String?
    let strMeasure4: String?
    let strMeasure5: String?
    let strMeasure6: String?
    let strMeasure7: String?
    let strMeasure8: String?
    let strMeasure9: String?
    let strMeasure10: String?
    let strMeasure11: String?
    let strMeasure12: String?
    let strMeasure13: String?
    let strMeasure14: String?
    let strMeasure15: String?
    let strMeasure16: String?
    let strMeasure17: String?
    let strMeasure18: String?
    let strMeasure19: String?
    let strMeasure20: String?

    var asDomainRecipe: MealDBRecipe {
        MealDBRecipe(
            id: idMeal,
            name: strMeal,
            thumbnailURL: strMealThumb.flatMap(URL.init(string:)),
            category: Self.nonEmpty(strCategory),
            area: Self.nonEmpty(strArea),
            country: Self.nonEmpty(strCountry),
            instructions: Self.nonEmpty(strInstructions),
            tags: Self.parseTags(strTags),
            youtubeURL: Self.nonEmpty(strYoutube).flatMap(URL.init(string:)),
            sourceURL: Self.nonEmpty(strSource).flatMap(URL.init(string:)),
            ingredients: packedIngredients
        )
    }

    private var packedIngredients: [MealDBIngredient] {
        let pairs: [(String?, String?)] = [
            (strIngredient1, strMeasure1),
            (strIngredient2, strMeasure2),
            (strIngredient3, strMeasure3),
            (strIngredient4, strMeasure4),
            (strIngredient5, strMeasure5),
            (strIngredient6, strMeasure6),
            (strIngredient7, strMeasure7),
            (strIngredient8, strMeasure8),
            (strIngredient9, strMeasure9),
            (strIngredient10, strMeasure10),
            (strIngredient11, strMeasure11),
            (strIngredient12, strMeasure12),
            (strIngredient13, strMeasure13),
            (strIngredient14, strMeasure14),
            (strIngredient15, strMeasure15),
            (strIngredient16, strMeasure16),
            (strIngredient17, strMeasure17),
            (strIngredient18, strMeasure18),
            (strIngredient19, strMeasure19),
            (strIngredient20, strMeasure20),
        ]

        return pairs.compactMap { name, measure in
            guard let trimmedName = Self.nonEmpty(name) else { return nil }
            return MealDBIngredient(
                name: trimmedName,
                measure: Self.nonEmpty(measure) ?? ""
            )
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func parseTags(_ raw: String?) -> [String] {
        guard let raw = nonEmpty(raw) else { return [] }
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

/// Wire row for `list.php?a=list` / `c=list` / `i=list`.
struct MealDBNamedListDTO: Decodable, Sendable {
    let strArea: String?
    let strCategory: String?
    let strIngredient: String?
    let idIngredient: String?
}
