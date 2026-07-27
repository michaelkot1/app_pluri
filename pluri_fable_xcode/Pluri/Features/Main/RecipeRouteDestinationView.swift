import SwiftUI

/// Resolves a pushed `RecipeRoute` to its destination view (M7-09).
struct RecipeRouteDestinationView: View {
    var route: RecipeRoute

    var body: some View {
        switch route {
        case .detail(let mealID):
            RecipeDetailView(mealID: mealID)
        }
    }
}
