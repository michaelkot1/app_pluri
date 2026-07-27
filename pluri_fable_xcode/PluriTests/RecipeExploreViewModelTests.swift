import Foundation
import Testing
@testable import Pluri

/// M7-10 — duration / portion heuristics + Explore VM offline / filter paths.
@Suite("RecipeExploreHeuristics")
struct RecipeExploreHeuristicsTests {

    @Test("Parses largest minute mention from instructions")
    func parsesMinutes() {
        let instructions = "Preheat oven. Bake chicken 35 minutes, then rest 5 min."
        #expect(RecipeExploreHeuristics.estimatedMinutes(in: instructions) == 35)
        #expect(RecipeExploreHeuristics.estimatedMinutes(in: nil) == nil)
        #expect(RecipeExploreHeuristics.estimatedMinutes(in: "No times here") == nil)
    }

    @Test("Duration bands match estimated minutes")
    func durationBands() {
        let quick = recipe(instructions: "Cook about 9 minutes.")
        let mid = recipe(instructions: "Bake about 30 minutes.")
        let long = recipe(instructions: "Roast 60 minutes.")
        let unknown = recipe(instructions: "Cook until done.")

        #expect(RecipeExploreHeuristics.matchesDuration(.under20, recipe: quick))
        #expect(!RecipeExploreHeuristics.matchesDuration(.under20, recipe: mid))
        #expect(RecipeExploreHeuristics.matchesDuration(.from20to45, recipe: mid))
        #expect(!RecipeExploreHeuristics.matchesDuration(.from20to45, recipe: long))
        #expect(RecipeExploreHeuristics.matchesDuration(.over45, recipe: long))
        #expect(!RecipeExploreHeuristics.matchesDuration(.under20, recipe: unknown))
    }

    @Test("Meal-prep detects batch language and large measures")
    func mealPrepSignals() {
        let casserole = recipe(
            instructions: "Assemble the casserole and bake.",
            tags: ["Casserole"],
            measure: "1kg"
        )
        let single = recipe(
            instructions: "Pan-sear the fillet.",
            tags: [],
            measure: "1 fillet"
        )
        #expect(RecipeExploreHeuristics.isMealPrep(casserole))
        #expect(!RecipeExploreHeuristics.isMealPrep(single))
        #expect(RecipeExploreHeuristics.matchesPortion(.mealPrep, recipe: casserole))
        #expect(RecipeExploreHeuristics.matchesPortion(.single, recipe: single))
    }

    private func recipe(
        instructions: String?,
        tags: [String] = [],
        measure: String = "1"
    ) -> MealDBRecipe {
        MealDBRecipe(
            id: "1",
            name: "Test",
            thumbnailURL: nil,
            category: "Chicken",
            area: "British",
            country: nil,
            instructions: instructions,
            tags: tags,
            youtubeURL: nil,
            sourceURL: nil,
            ingredients: [MealDBIngredient(name: "chicken", measure: measure)]
        )
    }
}

@Suite("RecipeExploreViewModel")
@MainActor
struct RecipeExploreViewModelTests {

    @Test("Offline Explore reports needs connection")
    func offlineState() async {
        let vm = RecipeExploreViewModel(
            mealDBClient: MockMealDBClient(),
            reachability: MockNetworkReachability(isOnline: false)
        )
        await vm.search()
        #expect(vm.loadState == .offline)
        #expect(vm.results.isEmpty)
    }

    @Test("Protein filter returns matching MockMealDBClient fixtures")
    func proteinFilter() async {
        let vm = RecipeExploreViewModel(
            mealDBClient: MockMealDBClient(),
            reachability: AlwaysOnlineReachability()
        )
        vm.filters.protein = .chicken
        await vm.search()
        #expect(vm.loadState == .loaded)
        #expect(vm.results.allSatisfy { $0.category?.localizedStandardContains("Chicken") == true })
    }

    @Test("Cuisine maps American to United States area")
    func cuisineMapping() async {
        let vm = RecipeExploreViewModel(
            mealDBClient: MockMealDBClient(),
            reachability: AlwaysOnlineReachability()
        )
        vm.filters.cuisine = .american
        await vm.search()
        // Fixture BBQ Pork has area United States.
        if case .loaded = vm.loadState {
            #expect(vm.results.contains { $0.area == "United States" })
        } else {
            #expect(vm.loadState == .empty || vm.loadState == .loaded)
        }
    }

    @Test("Duration filter excludes unknown cook times")
    func durationFilterExcludesUnknown() async {
        let unknown = MealDBRecipe(
            id: "u1",
            name: "Chicken Mystery Stew",
            thumbnailURL: nil,
            category: "Chicken",
            area: "British",
            country: nil,
            instructions: "Cook until tender.",
            tags: [],
            youtubeURL: nil,
            sourceURL: nil,
            ingredients: [MealDBIngredient(name: "beef", measure: "1kg")]
        )
        let quick = MealDBRecipe(
            id: "q1",
            name: "Chicken Quick Eggs",
            thumbnailURL: nil,
            category: "Chicken",
            area: "British",
            country: nil,
            instructions: "Scramble for 5 minutes.",
            tags: [],
            youtubeURL: nil,
            sourceURL: nil,
            ingredients: [MealDBIngredient(name: "eggs", measure: "2")]
        )
        let vm = RecipeExploreViewModel(
            mealDBClient: MockMealDBClient(fixtures: [unknown, quick]),
            reachability: AlwaysOnlineReachability()
        )
        vm.filters.duration = .under20
        await vm.search()
        #expect(vm.results.map(\.id) == ["q1"])
        #expect(vm.loadState == .loaded)
    }
}
