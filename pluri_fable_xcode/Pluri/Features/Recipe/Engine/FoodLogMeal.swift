import Foundation

/// Meal tags for `food_logs.meal` (SPEC §14 #67f).
///
/// Includes `snack`, which is food-log only and is not a day-suggestion
/// `MealSlot`. Raw values match the Postgres check constraint.
nonisolated enum FoodLogMeal: String, CaseIterable, Sendable, Hashable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case dessert
    case snack

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .dessert: "Dessert"
        case .snack: "Snack"
        }
    }

    /// Maps a suggestion slot when logging from a day section context.
    init(slot: MealSlot) {
        switch slot {
        case .breakfast: self = .breakfast
        case .lunch: self = .lunch
        case .dinner: self = .dinner
        case .dessert: self = .dessert
        }
    }
}
