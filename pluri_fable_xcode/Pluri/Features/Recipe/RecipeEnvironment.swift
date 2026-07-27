import SwiftUI

/// Environment injection for TheMealDB + Nutrition networking (M7-08 / M7-11).
/// Mirrors Ask Pluri — default mocks for previews/tests; live clients wired in
/// `AppRootView`.
private struct MealDBClientKey: EnvironmentKey {
    static let defaultValue: any MealDBClient = MockMealDBClient()
}

private struct NutritionClientKey: EnvironmentKey {
    static let defaultValue: any NutritionClient = MockNutritionClient()
}

extension EnvironmentValues {
    var mealDBClient: any MealDBClient {
        get { self[MealDBClientKey.self] }
        set { self[MealDBClientKey.self] = newValue }
    }

    var nutritionClient: any NutritionClient {
        get { self[NutritionClientKey.self] }
        set { self[NutritionClientKey.self] = newValue }
    }
}
