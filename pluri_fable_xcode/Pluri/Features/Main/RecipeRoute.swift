import Foundation

/// Typed destinations pushable from the Recipe tab's `NavigationStack`
/// (M7-08/09 / SPEC §12).
enum RecipeRoute: Hashable, Sendable {
    /// Full MealDB recipe detail keyed by `idMeal`.
    case detail(mealID: String)
}
