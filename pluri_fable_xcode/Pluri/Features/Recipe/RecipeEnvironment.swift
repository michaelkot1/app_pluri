import SwiftUI

/// Environment injection for TheMealDB networking (M7-08).
/// Mirrors Ask Pluri — default mock for previews/tests; live client wired in
/// `AppRootView`.
private struct MealDBClientKey: EnvironmentKey {
    static let defaultValue: any MealDBClient = MockMealDBClient()
}

extension EnvironmentValues {
    var mealDBClient: any MealDBClient {
        get { self[MealDBClientKey.self] }
        set { self[MealDBClientKey.self] = newValue }
    }
}
