import Foundation
import SwiftData

/// Persisted day suggestions for offline Recipe Day (M7-08 / SPEC §14 #67g).
///
/// Stores the engine output for one user + calendar day so returning offline
/// still shows last-cached picks — never invents MealDB content.
@Model
final class RecipeDaySuggestionsRecord {
    #Unique<RecipeDaySuggestionsRecord>([\.userId, \.dayKey])

    var id: UUID = UUID()
    var userId: UUID = UUID()
    /// Local calendar day as `yyyy-MM-dd`.
    var dayKey: String = ""
    /// JSON-encoded `RecipeDaySuggestionsPayload`.
    var payloadJSON: Data = Data()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        userId: UUID,
        dayKey: String,
        payloadJSON: Data,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.dayKey = dayKey
        self.payloadJSON = payloadJSON
        self.updatedAt = updatedAt
    }
}

/// Codable snapshot of `RecipeSuggestionEngine.DaySuggestions`.
struct RecipeDaySuggestionsPayload: Codable, Sendable, Equatable {
    var breakfast: [MealDBRecipe]
    var lunch: [MealDBRecipe]
    var dinner: [MealDBRecipe]
    var dessert: [MealDBRecipe]

    init(from suggestions: RecipeSuggestionEngine.DaySuggestions) {
        breakfast = suggestions.breakfast
        lunch = suggestions.lunch
        dinner = suggestions.dinner
        dessert = suggestions.dessert
    }

    var asDaySuggestions: RecipeSuggestionEngine.DaySuggestions {
        RecipeSuggestionEngine.DaySuggestions(
            breakfast: breakfast,
            lunch: lunch,
            dinner: dinner,
            dessert: dessert
        )
    }
}
