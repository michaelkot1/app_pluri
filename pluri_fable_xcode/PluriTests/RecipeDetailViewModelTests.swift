import Foundation
import SwiftData
import Testing
@testable import Pluri

/// M7-09 — RecipeDetailViewModel lookup / favorite / offline honesty.
@Suite("RecipeDetailViewModel")
@MainActor
struct RecipeDetailViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema([
                RecipeFavoriteRecord.self,
                RecipeDaySuggestionsRecord.self,
                RecipeCandidatePoolRecord.self,
            ]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Lookup loads full recipe when online")
    func lookupOnline() async throws {
        let container = try makeContainer()
        let recipe = [MealDBRecipe].mealDBPreviewFixtures[0]
        let vm = RecipeDetailViewModel(
            mealID: recipe.id,
            mealDBClient: MockMealDBClient(),
            modelContext: container.mainContext,
            userId: UUID(),
            reachability: AlwaysOnlineReachability()
        )
        await vm.load()
        #expect(vm.loadState == .loaded)
        #expect(vm.recipe?.id == recipe.id)
        #expect(!(vm.recipe?.ingredients.isEmpty ?? true))
    }

    @Test("Offline without seed reports offline")
    func offlineNoSeed() async throws {
        let container = try makeContainer()
        let vm = RecipeDetailViewModel(
            mealID: "52771",
            mealDBClient: MockMealDBClient(),
            modelContext: container.mainContext,
            userId: UUID(),
            reachability: MockNetworkReachability(isOnline: false)
        )
        await vm.load()
        #expect(vm.loadState == .offline)
    }

    @Test("Favorite toggle never requires network")
    func favoriteToggleLocal() async throws {
        let container = try makeContainer()
        let recipe = [MealDBRecipe].mealDBPreviewFixtures[0]
        let vm = RecipeDetailViewModel(
            mealID: recipe.id,
            mealDBClient: MockMealDBClient(),
            modelContext: container.mainContext,
            userId: UUID(),
            seedRecipe: recipe,
            reachability: MockNetworkReachability(isOnline: false)
        )
        await vm.load()
        #expect(vm.isFavorite == false)
        vm.toggleFavorite()
        #expect(vm.isFavorite == true)
        vm.toggleFavorite()
        #expect(vm.isFavorite == false)
    }

    @Test("Log stub surfaces coming soon")
    func logStub() async throws {
        let container = try makeContainer()
        let recipe = [MealDBRecipe].mealDBPreviewFixtures[0]
        let vm = RecipeDetailViewModel(
            mealID: recipe.id,
            mealDBClient: MockMealDBClient(),
            modelContext: container.mainContext,
            userId: UUID(),
            seedRecipe: recipe,
            reachability: AlwaysOnlineReachability()
        )
        await vm.load()
        vm.tapLogStub()
        #expect(vm.showsLogComingSoon)
    }
}
