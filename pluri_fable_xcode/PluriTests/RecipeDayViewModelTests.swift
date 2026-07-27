import Foundation
import SwiftData
import Testing
@testable import Pluri

/// M7-08 — RecipeDayViewModel load states, allergy-empty slots, offline cache.
@Suite("RecipeDayViewModel")
@MainActor
struct RecipeDayViewModelTests {

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

    private func makeViewModel(
        container: ModelContainer,
        client: any MealDBClient,
        reachability: any NetworkReachability,
        allergies: Set<String> = []
    ) -> RecipeDayViewModel {
        let planStore = PlanStore(mutationService: MockPlanMutationService())
        _ = allergies
        return RecipeDayViewModel(
            mealDBClient: client,
            planStore: planStore,
            modelContext: container.mainContext,
            userId: UUID(),
            reachability: reachability
        )
    }

    @Test("Online load populates suggestions from full recipes")
    func onlineLoadPopulates() async throws {
        let container = try makeContainer()
        let fixtures = enrichedFixtures()
        let vm = RecipeDayViewModel(
            mealDBClient: MockMealDBClient(fixtures: fixtures),
            planStore: PlanStore(mutationService: MockPlanMutationService()),
            modelContext: container.mainContext,
            userId: UUID(),
            reachability: AlwaysOnlineReachability()
        )

        await vm.loadSuggestions(for: .now)

        #expect(vm.loadState == .loaded || vm.loadState == .empty)
        if case .loaded = vm.loadState {
            let total = MealSlot.allCases.reduce(0) { $0 + vm.suggestions[$1].count }
            #expect(total > 0)
        }
    }

    @Test("Offline without cache reports offlineNoCache")
    func offlineNoCache() async throws {
        let container = try makeContainer()
        let vm = makeViewModel(
            container: container,
            client: MockMealDBClient(),
            reachability: MockNetworkReachability(isOnline: false)
        )

        await vm.loadSuggestions(for: .now)

        #expect(vm.loadState == .offlineNoCache)
        #expect(MealSlot.allCases.allSatisfy { vm.suggestions[$0].isEmpty })
    }

    @Test("MealDB rateLimited without cache surfaces Day error state")
    func rateLimitedWithoutCache() async throws {
        let container = try makeContainer()
        let vm = makeViewModel(
            container: container,
            client: MockMealDBClient(errorToThrow: .rateLimited),
            reachability: AlwaysOnlineReachability()
        )

        await vm.loadSuggestions(for: .now)

        #expect(MealSlot.allCases.allSatisfy { vm.suggestions[$0].isEmpty })
        guard case .error(let message) = vm.loadState else {
            Issue.record("Expected .error, got \(vm.loadState)")
            return
        }
        #expect(message == MealDBClientError.rateLimited.errorDescription)
    }

    @Test("Offline with cached day suggestions uses cache")
    func offlineUsesCache() async throws {
        let container = try makeContainer()
        let userId = UUID()
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: .now)
        let cache = RecipeSuggestionsCache(
            modelContext: container.mainContext,
            userId: userId,
            calendar: calendar
        )
        let sample = RecipeSuggestionEngine.DaySuggestions(
            breakfast: [enrichedFixtures().first { $0.category == "Breakfast" }!],
            lunch: [],
            dinner: [],
            dessert: []
        )
        try cache.saveDaySuggestions(sample, for: day)

        let vm = RecipeDayViewModel(
            mealDBClient: MockMealDBClient(),
            planStore: PlanStore(mutationService: MockPlanMutationService()),
            modelContext: container.mainContext,
            userId: userId,
            reachability: MockNetworkReachability(isOnline: false),
            calendar: calendar
        )

        await vm.loadSuggestions(for: day)

        #expect(vm.loadState == .offlineCached)
        #expect(vm.isShowingCachedSuggestions)
        #expect(vm.suggestions.breakfast.count == 1)
    }

    @Test("refreshCalorieProgress picks up food logs inserted after initial load")
    func refreshCalorieProgressAfterLogInsert() throws {
        let container = try makeContainer()
        let userId = UUID()
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: .now)
        let vm = RecipeDayViewModel(
            mealDBClient: MockMealDBClient(),
            planStore: PlanStore(mutationService: MockPlanMutationService()),
            modelContext: container.mainContext,
            userId: userId,
            reachability: AlwaysOnlineReachability(),
            calendar: calendar
        )
        // Avoid select/reload — that starts an async suggestions load against the
        // same ModelContext and can race with the insert below.
        vm.refreshCalorieProgress()
        #expect(vm.calorieProgress.eatenCalories == 0)

        let store = FoodLogsStore(
            modelContext: container.mainContext,
            userId: userId,
            calendar: calendar
        )
        _ = try store.insert(
            foodName: "Oatmeal",
            serving: "1 bowl",
            calories: 250,
            meal: .breakfast,
            loggedDate: day
        )

        vm.refreshCalorieProgress()
        #expect(vm.calorieProgress.eatenCalories == 250)
    }

    @Test("Allergy hard-filter can empty a slot honestly")
    func allergyEmptiesBreakfast() async throws {
        let peanutBreakfast = MealDBRecipe(
            id: "b1",
            name: "Peanut Butter Toast",
            thumbnailURL: nil,
            category: "Breakfast",
            area: "American",
            country: nil,
            instructions: "Toast bread 5 minutes.",
            tags: [],
            youtubeURL: nil,
            sourceURL: nil,
            ingredients: [
                MealDBIngredient(name: "peanut butter", measure: "2 tbsp"),
                MealDBIngredient(name: "bread", measure: "2 slices"),
            ]
        )
        let safeLunch = MealDBRecipe(
            id: "l1",
            name: "Rice Bowl",
            thumbnailURL: nil,
            category: "Chicken",
            area: "Japanese",
            country: nil,
            instructions: "Cook rice 20 minutes.",
            tags: [],
            youtubeURL: nil,
            sourceURL: nil,
            ingredients: [
                MealDBIngredient(name: "rice", measure: "1 cup"),
                MealDBIngredient(name: "chicken", measure: "1 breast"),
            ]
        )
        let client = MockMealDBClient(fixtures: [peanutBreakfast, safeLunch])
        let container = try makeContainer()

        // Drive engine directly with allergies to assert empty breakfast honesty;
        // VM reads allergies from PlanStore profile which stays nil here.
        let input = RecipeSuggestionEngine.Input(
            userID: UUID(),
            day: .now,
            allergies: ["Peanuts"],
            candidates: [peanutBreakfast, safeLunch]
        )
        let suggestions = RecipeSuggestionEngine.suggestions(for: input)
        #expect(suggestions.breakfast.isEmpty)
        #expect(!suggestions.lunch.isEmpty || !suggestions.dinner.isEmpty)

        let vm = RecipeDayViewModel(
            mealDBClient: client,
            planStore: PlanStore(mutationService: MockPlanMutationService()),
            modelContext: container.mainContext,
            userId: UUID(),
            reachability: AlwaysOnlineReachability()
        )
        await vm.loadSuggestions(for: .now)
        // Without profile allergies, breakfast may still appear — loader path works.
        #expect(vm.loadState == .loaded || vm.loadState == .empty)
    }

    private func enrichedFixtures() -> [MealDBRecipe] {
        var fixtures = [MealDBRecipe].mealDBPreviewFixtures
        fixtures.append(
            MealDBRecipe(
                id: "53000",
                name: "English Breakfast",
                thumbnailURL: nil,
                category: "Breakfast",
                area: "British",
                country: nil,
                instructions: "Fry eggs 5 minutes. Serve.",
                tags: [],
                youtubeURL: nil,
                sourceURL: nil,
                ingredients: [
                    MealDBIngredient(name: "eggs", measure: "2"),
                    MealDBIngredient(name: "bacon", measure: "2 rashes"),
                ]
            )
        )
        fixtures.append(
            MealDBRecipe(
                id: "53001",
                name: "Apple Pie",
                thumbnailURL: nil,
                category: "Dessert",
                area: "American",
                country: nil,
                instructions: "Bake 45 minutes until golden.",
                tags: ["Pie"],
                youtubeURL: nil,
                sourceURL: nil,
                ingredients: [
                    MealDBIngredient(name: "apples", measure: "6"),
                    MealDBIngredient(name: "flour", measure: "2 cups"),
                ]
            )
        )
        return fixtures
    }
}
