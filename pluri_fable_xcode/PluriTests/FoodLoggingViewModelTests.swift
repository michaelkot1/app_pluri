import Foundation
import SwiftData
import Testing
@testable import Pluri

/// M7-11 — FoodLoggingViewModel search honesty + nil-kcal gate.
@Suite("FoodLoggingViewModel")
@MainActor
struct FoodLoggingViewModelTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema([FoodLogRecord.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeStore(
        in container: ModelContainer,
        sync: MockSyncEngine? = nil
    ) -> FoodLogsStore {
        let engine = sync ?? MockSyncEngine()
        engine.flushOnEnqueue = false
        return FoodLogsStore(
            modelContext: container.mainContext,
            userId: UUID(),
            syncEngine: engine
        )
    }

    @Test("Search success returns matching fixtures")
    func searchSuccess() async throws {
        let container = try makeContainer()
        let vm = FoodLoggingViewModel(
            context: .standalone(loggedDate: .now),
            nutritionClient: MockNutritionClient(),
            foodLogsStore: makeStore(in: container),
            reachability: AlwaysOnlineReachability()
        )
        vm.searchQuery = "apple"
        vm.onSearchQueryChanged()
        try await Task.sleep(for: .milliseconds(500))
        #expect(vm.searchState == .results)
        #expect(vm.results.contains(where: { $0.name == "apple" }))
    }

    @Test("Empty search results surface empty state")
    func searchEmpty() async throws {
        let container = try makeContainer()
        let vm = FoodLoggingViewModel(
            context: .standalone(loggedDate: .now),
            nutritionClient: MockNutritionClient(),
            foodLogsStore: makeStore(in: container),
            reachability: AlwaysOnlineReachability()
        )
        vm.searchQuery = "zzzz-not-a-food"
        vm.onSearchQueryChanged()
        try await Task.sleep(for: .milliseconds(500))
        #expect(vm.searchState == .empty)
        #expect(vm.results.isEmpty)
    }

    @Test("Offline search is honest — no invented results")
    func searchOffline() async throws {
        let container = try makeContainer()
        let vm = FoodLoggingViewModel(
            context: .standalone(loggedDate: .now),
            nutritionClient: MockNutritionClient(),
            foodLogsStore: makeStore(in: container),
            reachability: MockNetworkReachability(isOnline: false)
        )
        vm.searchQuery = "apple"
        vm.onSearchQueryChanged()
        try await Task.sleep(for: .milliseconds(500))
        #expect(vm.searchState == .offline)
        #expect(vm.results.isEmpty)
    }

    @Test("Unauthorized Nutrition error surfaces error state with copy")
    func searchUnauthorized() async throws {
        let container = try makeContainer()
        let vm = FoodLoggingViewModel(
            context: .standalone(loggedDate: .now),
            nutritionClient: MockNutritionClient(errorToThrow: .unauthorized),
            foodLogsStore: makeStore(in: container),
            reachability: AlwaysOnlineReachability()
        )
        vm.searchQuery = "apple"
        vm.onSearchQueryChanged()
        try await Task.sleep(for: .milliseconds(500))
        #expect(vm.results.isEmpty)
        guard case .error(let message) = vm.searchState else {
            Issue.record("Expected .error, got \(vm.searchState)")
            return
        }
        #expect(message == NutritionClientError.unauthorized.errorDescription)
    }

    @Test("Rate-limited Nutrition error surfaces error state with copy")
    func searchRateLimited() async throws {
        let container = try makeContainer()
        let vm = FoodLoggingViewModel(
            context: .standalone(loggedDate: .now),
            nutritionClient: MockNutritionClient(errorToThrow: .rateLimited),
            foodLogsStore: makeStore(in: container),
            reachability: AlwaysOnlineReachability()
        )
        vm.searchQuery = "apple"
        vm.onSearchQueryChanged()
        try await Task.sleep(for: .milliseconds(500))
        #expect(vm.results.isEmpty)
        guard case .error(let message) = vm.searchState else {
            Issue.record("Expected .error, got \(vm.searchState)")
            return
        }
        #expect(message == NutritionClientError.rateLimited.errorDescription)
    }

    @Test("Transport Nutrition error maps to offline honesty")
    func searchTransportMapsOffline() async throws {
        let container = try makeContainer()
        let vm = FoodLoggingViewModel(
            context: .standalone(loggedDate: .now),
            nutritionClient: MockNutritionClient(errorToThrow: .transport("timeout")),
            foodLogsStore: makeStore(in: container),
            reachability: AlwaysOnlineReachability()
        )
        vm.searchQuery = "apple"
        vm.onSearchQueryChanged()
        try await Task.sleep(for: .milliseconds(500))
        #expect(vm.searchState == .offline)
        #expect(vm.results.isEmpty)
    }

    @Test("Nil-kcal selection blocks save with honest message")
    func nilKcalHonesty() throws {
        let container = try makeContainer()
        let store = makeStore(in: container)
        let vm = FoodLoggingViewModel(
            context: .standalone(loggedDate: .now),
            nutritionClient: MockNutritionClient(),
            foodLogsStore: store,
            reachability: AlwaysOnlineReachability()
        )
        let brisket = [NutritionFood].nutritionPreviewFixtures.first { $0.calories == nil }!
        vm.searchQuery = "1 lb brisket"
        vm.selectFood(brisket)
        #expect(vm.canSave == false)
        #expect(vm.saveErrorMessage == FoodLoggingViewModel.nilCaloriesMessage)
        #expect(vm.save() == false)
        #expect(try store.logs(on: .now).isEmpty)
    }

    @Test("Known-kcal selection saves and updates day total")
    func saveKnownCalories() throws {
        let container = try makeContainer()
        let store = makeStore(in: container)
        let day = Calendar.current.startOfDay(for: .now)
        let vm = FoodLoggingViewModel(
            context: .standalone(loggedDate: day, meal: .lunch),
            nutritionClient: MockNutritionClient(),
            foodLogsStore: store,
            reachability: AlwaysOnlineReachability()
        )
        let apple = [NutritionFood].nutritionPreviewFixtures.first { $0.name == "apple" }!
        vm.searchQuery = "1 apple"
        vm.selectFood(apple)
        #expect(vm.canSave)
        #expect(vm.save())
        #expect(try store.dayCalorieTotal(on: day) == 95)
        let log = try store.logs(on: day).first
        #expect(log?.mealTag == .lunch)
        #expect(log?.serving == "1 apple")
    }

    @Test("Recipe prefill seeds query and mealdb id")
    func recipePrefill() throws {
        let container = try makeContainer()
        let recipe = [MealDBRecipe].mealDBPreviewFixtures[0]
        let context = FoodLoggingContext.fromRecipe(recipe, loggedDate: .now, meal: .dinner)
        let vm = FoodLoggingViewModel(
            context: context,
            nutritionClient: MockNutritionClient(),
            foodLogsStore: makeStore(in: container),
            reachability: AlwaysOnlineReachability()
        )
        #expect(vm.searchQuery == recipe.name)
        #expect(vm.mealdbRecipeId == recipe.id)
        #expect(vm.meal == .dinner)
        #expect(vm.recipeTitle == recipe.name)
    }
}
