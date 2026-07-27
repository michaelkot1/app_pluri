import Foundation
import Testing
@testable import Pluri

/// M7-06 — RecipeSuggestionEngine: seed stability, allergy hard-filter,
/// honest empty slots, favorites similarity boost, soft kcal bias / neutral.
@Suite("RecipeSuggestionEngine")
struct RecipeSuggestionEngineTests {

    // MARK: Fixtures

    private let userID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private var day: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 26))!
    }

    /// Full recipes spanning Breakfast / Dessert / main categories for pooling.
    private func makeCandidates() -> [MealDBRecipe] {
        [
            recipe(
                id: "b1", name: "Pancakes", category: "Breakfast", area: "American",
                ingredients: ["flour", "milk", "egg", "butter"]
            ),
            recipe(
                id: "b2", name: "Oatmeal", category: "Breakfast", area: "American",
                ingredients: ["oats", "water", "banana"]
            ),
            recipe(
                id: "b3", name: "Veggie Omelette", category: "Breakfast", area: "French",
                ingredients: ["egg", "spinach", "tomato"]
            ),
            recipe(
                id: "b4", name: "Peanut Butter Toast", category: "Breakfast", area: "American",
                ingredients: ["bread", "peanut butter"]
            ),
            recipe(
                id: "l1", name: "Chicken Salad", category: "Chicken", area: "American",
                ingredients: ["chicken breasts", "lettuce", "olive oil"]
            ),
            recipe(
                id: "l2", name: "Beef Bowl", category: "Beef", area: "Japanese",
                ingredients: ["beef", "rice", "soy sauce"]
            ),
            recipe(
                id: "l3", name: "Salmon Plate", category: "Seafood", area: "British",
                ingredients: ["salmon", "fennel", "cherry tomatoes"]
            ),
            recipe(
                id: "l4", name: "Vegan Pasta", category: "Vegan", area: "Italian",
                ingredients: ["penne rigate", "tomato sauce", "garlic"]
            ),
            recipe(
                id: "l5", name: "Pork Tacos", category: "Pork", area: "Mexican",
                ingredients: ["pork mince", "tortilla", "salsa"]
            ),
            recipe(
                id: "d1", name: "Apple Pie", category: "Dessert", area: "American",
                ingredients: ["apple", "flour", "butter", "sugar"]
            ),
            recipe(
                id: "d2", name: "Chocolate Mousse", category: "Dessert", area: "French",
                ingredients: ["chocolate", "cream", "egg"]
            ),
            recipe(
                id: "d3", name: "Fruit Salad", category: "Dessert", area: "American",
                ingredients: ["apple", "banana", "orange"]
            ),
            recipe(
                id: "d4", name: "Peanut Cookies", category: "Dessert", area: "American",
                ingredients: ["peanut", "sugar", "flour"]
            ),
        ]
    }

    private func recipe(
        id: String,
        name: String,
        category: String,
        area: String,
        ingredients: [String]
    ) -> MealDBRecipe {
        MealDBRecipe(
            id: id,
            name: name,
            thumbnailURL: nil,
            category: category,
            area: area,
            country: nil,
            instructions: "Cook \(name).",
            tags: [],
            youtubeURL: nil,
            sourceURL: nil,
            ingredients: ingredients.map { MealDBIngredient(name: $0, measure: "1") }
        )
    }

    private func makeInput(
        allergies: [String] = [],
        maintenanceCalories: Int? = 2_000,
        favorites: [MealDBRecipe] = [],
        caloriesByRecipeID: [String: Int] = [:]
    ) -> RecipeSuggestionEngine.Input {
        RecipeSuggestionEngine.Input(
            userID: userID,
            day: day,
            allergies: allergies,
            maintenanceCalories: maintenanceCalories,
            candidates: makeCandidates(),
            favorites: favorites,
            caloriesByRecipeID: caloriesByRecipeID,
            calendar: calendar
        )
    }

    private func isBreakfastOrDessert(_ recipe: MealDBRecipe) -> Bool {
        let category = recipe.category ?? ""
        return category.localizedStandardContains("Breakfast")
            || category.localizedStandardContains("Dessert")
    }

    // MARK: Seed

    @Test("Same user/day/slot seed is stable; different slots diverge")
    func seedStability() {
        let a = RecipeSuggestionEngine.deterministicSeed(
            userID: userID, day: day, slot: .breakfast, calendar: calendar
        )
        let b = RecipeSuggestionEngine.deterministicSeed(
            userID: userID, day: day, slot: .breakfast, calendar: calendar
        )
        let lunch = RecipeSuggestionEngine.deterministicSeed(
            userID: userID, day: day, slot: .lunch, calendar: calendar
        )
        #expect(a == b)
        #expect(a != lunch)
    }

    @Test("Same inputs produce identical day suggestions")
    func deterministicSuggestions() {
        let input = makeInput()
        let first = RecipeSuggestionEngine.suggestions(for: input)
        let second = RecipeSuggestionEngine.suggestions(for: input)
        #expect(first == second)
        #expect(first.breakfast.count == RecipeSuggestionEngine.optionsPerSlot)
        #expect(first.lunch.count == RecipeSuggestionEngine.optionsPerSlot)
        #expect(first.dinner.count == RecipeSuggestionEngine.optionsPerSlot)
        #expect(first.dessert.count == RecipeSuggestionEngine.optionsPerSlot)
    }

    // MARK: Allergy

    @Test("Peanut allergy hard-filters peanut recipes from every slot")
    func allergyExclusion() {
        let input = makeInput(allergies: ["Peanuts"])
        let result = RecipeSuggestionEngine.suggestions(for: input)
        let breakfastIDs = result.breakfast.map(\.id)
        let lunchIDs = result.lunch.map(\.id)
        let dinnerIDs = result.dinner.map(\.id)
        let dessertIDs = result.dessert.map(\.id)
        let allIDs = breakfastIDs + lunchIDs + dinnerIDs + dessertIDs
        #expect(!allIDs.contains("b4"))
        #expect(!allIDs.contains("d4"))
        let peanutToast = makeCandidates().first { $0.id == "b4" }!
        #expect(RecipeSuggestionEngine.containsAllergen(recipe: peanutToast, allergies: ["Peanuts"]))
    }

    @Test("When every candidate in a slot is unsafe, the slot is honestly empty")
    func honestEmptySlot() {
        let eggOnlyBreakfast = [
            recipe(
                id: "e1", name: "Egg Bowl", category: "Breakfast", area: "American",
                ingredients: ["egg", "salt"]
            ),
            recipe(
                id: "e2", name: "Egg Toast", category: "Breakfast", area: "American",
                ingredients: ["egg", "bread"]
            ),
        ]
        let input = RecipeSuggestionEngine.Input(
            userID: userID,
            day: day,
            allergies: ["Eggs"],
            maintenanceCalories: 2_000,
            candidates: eggOnlyBreakfast,
            calendar: calendar
        )
        let breakfast = RecipeSuggestionEngine.suggestions(for: .breakfast, input: input)
        #expect(breakfast.isEmpty)
    }

    // MARK: Similarity

    @Test("Favorites cuisine + ingredient overlap boosts similar recipes into picks")
    func similarityBoost() {
        let favorites = [
            recipe(
                id: "fav", name: "Favorite Italian", category: "Vegetarian", area: "Italian",
                ingredients: ["penne rigate", "tomato sauce", "garlic"]
            ),
        ]
        let mainCandidates = makeCandidates().filter { !isBreakfastOrDessert($0) }
        let scores = RecipeSuggestionEngine.similarityScores(
            candidates: mainCandidates,
            favorites: favorites
        )
        #expect((scores["l4"] ?? 0) > (scores["l1"] ?? 0))
        #expect((scores["l4"] ?? 0) > (scores["l5"] ?? 0))

        let rankedWith = RecipeSuggestionEngine.rankedCandidates(
            for: .lunch,
            input: makeInput(favorites: favorites)
        )
        let rankedWithout = RecipeSuggestionEngine.rankedCandidates(
            for: .lunch,
            input: makeInput(favorites: [])
        )
        #expect(rankedWith.first?.id == "l4")
        #expect(rankedWithout.first?.id != "l4" || rankedWithout.count > 1)

        let with = RecipeSuggestionEngine.suggestions(
            for: .lunch,
            input: makeInput(favorites: favorites)
        )
        #expect(with.count == RecipeSuggestionEngine.optionsPerSlot)
        // Soft sample from the boosted pool — Italian pasta should be among top ranks.
        #expect(Set(rankedWith.prefix(RecipeSuggestionEngine.optionsPerSlot).map(\.id)).contains("l4"))
    }

    // MARK: Calories

    @Test("Known kcal ranks in-band meals above far out-of-band; unknown stays neutral")
    func calorieBiasWhenKnown() {
        let calories: [String: Int] = [
            "l1": 600,
            "l2": 600,
            "l3": 1_800,
            "l4": 600,
            "l5": 600,
        ]
        let ranked = RecipeSuggestionEngine.rankedCandidates(
            for: .lunch,
            input: makeInput(caloriesByRecipeID: calories)
        )
        #expect(ranked.last?.id == "l3")
        let topIDs = Set(ranked.prefix(RecipeSuggestionEngine.optionsPerSlot).map(\.id))
        #expect(!topIDs.contains("l3"))

        let neutral = RecipeSuggestionEngine.suggestions(
            for: .lunch,
            input: makeInput(caloriesByRecipeID: [:])
        )
        #expect(neutral.count == RecipeSuggestionEngine.optionsPerSlot)
        let again = RecipeSuggestionEngine.suggestions(
            for: .lunch,
            input: makeInput(caloriesByRecipeID: [:])
        )
        #expect(neutral.map(\.id) == again.map(\.id))
    }

    @Test("Nil maintenance calories leaves kcal ranking neutral")
    func nilMaintenanceIsNeutral() {
        let calories: [String: Int] = [
            "l1": 600,
            "l3": 1_800,
        ]
        let a = RecipeSuggestionEngine.suggestions(
            for: .lunch,
            input: makeInput(maintenanceCalories: nil, caloriesByRecipeID: calories)
        )
        let b = RecipeSuggestionEngine.suggestions(
            for: .lunch,
            input: makeInput(maintenanceCalories: nil, caloriesByRecipeID: [:])
        )
        #expect(a.map(\.id) == b.map(\.id))
    }

    // MARK: Slot pooling

    @Test("Breakfast and dessert pools use MealDB categories; lunch/dinner share the rest")
    func slotPooling() {
        let all = makeCandidates()
        let breakfast = RecipeSuggestionEngine.candidates(for: .breakfast, from: all)
        let dessert = RecipeSuggestionEngine.candidates(for: .dessert, from: all)
        let lunch = RecipeSuggestionEngine.candidates(for: .lunch, from: all)
        let dinner = RecipeSuggestionEngine.candidates(for: .dinner, from: all)
        #expect(breakfast.allSatisfy { $0.category == "Breakfast" })
        #expect(dessert.allSatisfy { $0.category == "Dessert" })
        #expect(lunch.allSatisfy { $0.category != "Breakfast" && $0.category != "Dessert" })
        #expect(Set(lunch.map(\.id)) == Set(dinner.map(\.id)))
    }
}
