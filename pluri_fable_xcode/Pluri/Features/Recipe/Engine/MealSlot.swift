import Foundation

/// Meal sections on the Recipe day view (SPEC §12 / §14 #67).
///
/// Raw values match `food_logs.meal` / suggestion slot tags (`breakfast` …
/// `dessert`). `snack` is food-log only and is not a day-suggestion slot.
nonisolated enum MealSlot: String, CaseIterable, Sendable, Hashable {
    case breakfast
    case lunch
    case dinner
    case dessert
}
