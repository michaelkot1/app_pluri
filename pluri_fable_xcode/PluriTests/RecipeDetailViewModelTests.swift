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
                FoodLogRecord.self,
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

    @Test("MealDB rateLimited without seed surfaces error state")
    func rateLimitedWithoutSeed() async throws {
        let container = try makeContainer()
        let vm = RecipeDetailViewModel(
            mealID: "52771",
            mealDBClient: MockMealDBClient(errorToThrow: .rateLimited),
            modelContext: container.mainContext,
            userId: UUID(),
            reachability: AlwaysOnlineReachability()
        )
        await vm.load()
        #expect(vm.recipe == nil)
        guard case .error(let message) = vm.loadState else {
            Issue.record("Expected .error, got \(vm.loadState)")
            return
        }
        #expect(message == MealDBClientError.rateLimited.errorDescription)
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

    @Test("Log opens shared sheet context with recipe prefill — not stub")
    func logOpensWithRecipePrefill() async throws {
        let container = try makeContainer()
        let recipe = [MealDBRecipe].mealDBPreviewFixtures[0]
        let vm = RecipeDetailViewModel(
            mealID: recipe.id,
            mealDBClient: MockMealDBClient(),
            modelContext: container.mainContext,
            userId: UUID(),
            seedRecipe: recipe,
            reachability: AlwaysOnlineReachability(),
            initialMeal: .dinner
        )
        await vm.load()
        #expect(vm.isPresentingLogSheet == false)
        vm.openLog()
        #expect(vm.isPresentingLogSheet)
        let context = vm.foodLoggingContext
        #expect(context?.searchQuery == recipe.name)
        #expect(context?.mealdbRecipeId == recipe.id)
        #expect(context?.meal == .dinner)
        #expect(context?.recipeTitle == recipe.name)
    }
}
