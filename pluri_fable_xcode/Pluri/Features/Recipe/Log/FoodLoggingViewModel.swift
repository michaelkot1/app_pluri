import Foundation
import Observation
import SwiftData

/// Prefill / context for the shared food logging sheet (M7-11/12).
struct FoodLoggingContext: Equatable, Sendable {
    /// Calendar day to attribute the log to (start-of-day applied on save).
    var loggedDate: Date
    /// Seed search query (recipe title when logging from detail).
    var searchQuery: String
    var meal: FoodLogMeal
    var mealdbRecipeId: String?
    /// Soft label for UI (“from recipe”) — optional.
    var recipeTitle: String?

    static func standalone(loggedDate: Date, meal: FoodLogMeal = .snack) -> FoodLoggingContext {
        FoodLoggingContext(
            loggedDate: loggedDate,
            searchQuery: "",
            meal: meal,
            mealdbRecipeId: nil,
            recipeTitle: nil
        )
    }

    static func fromRecipe(
        _ recipe: MealDBRecipe,
        loggedDate: Date,
        meal: FoodLogMeal = .snack
    ) -> FoodLoggingContext {
        FoodLoggingContext(
            loggedDate: loggedDate,
            searchQuery: recipe.name,
            meal: meal,
            mealdbRecipeId: recipe.id,
            recipeTitle: recipe.name
        )
    }
}

/// Shared Log sheet logic (M7-11/12): Nutrition search, serving = query label,
/// meal tag, nil-kcal honesty, offline honesty — never invents calories.
@MainActor
@Observable
final class FoodLoggingViewModel {
    enum SearchState: Equatable {
        case idle
        case searching
        case results
        case empty
        case offline
        case error(String)
    }

    var searchQuery: String
    var meal: FoodLogMeal
    private(set) var loggedDate: Date
    private(set) var mealdbRecipeId: String?
    private(set) var recipeTitle: String?

    private(set) var searchState: SearchState = .idle
    private(set) var results: [NutritionFood] = []
    private(set) var selectedFood: NutritionFood?
    private(set) var saveErrorMessage: String?
    private(set) var didSave = false

    private let nutritionClient: any NutritionClient
    private let foodLogsStore: FoodLogsStore
    private let reachability: any NetworkReachability
    private var searchTask: Task<Void, Never>?

    /// Honest copy when a hit has no calories (SPEC §14 #68 interim).
    static let nilCaloriesMessage =
        "Calories aren’t available for this food on our current nutrition plan. Pick another result that shows calories, or try a different serving search."

    init(
        context: FoodLoggingContext,
        nutritionClient: any NutritionClient,
        foodLogsStore: FoodLogsStore,
        reachability: (any NetworkReachability)? = nil
    ) {
        self.searchQuery = context.searchQuery
        self.meal = context.meal
        self.loggedDate = context.loggedDate
        self.mealdbRecipeId = context.mealdbRecipeId
        self.recipeTitle = context.recipeTitle
        self.nutritionClient = nutritionClient
        self.foodLogsStore = foodLogsStore
        self.reachability = reachability ?? PathMonitorReachability()
        self.reachability.start()
    }

    var selectedFoodHasCalories: Bool {
        selectedFood?.calories != nil
    }

    var canSave: Bool {
        guard let selectedFood, let calories = selectedFood.calories else { return false }
        let serving = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return !serving.isEmpty && calories >= 0 && !selectedFood.name.isEmpty
    }

    /// Serving label persisted on the log — user query text (Nutrition README).
    var servingLabel: String {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (selectedFood?.name ?? "") : trimmed
    }

    func onSearchQueryChanged() {
        selectedFood = nil
        saveErrorMessage = nil
        searchTask?.cancel()
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []
            searchState = .idle
            return
        }
        searchState = .searching
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self?.performSearch()
        }
    }

    func selectFood(_ food: NutritionFood) {
        selectedFood = food
        saveErrorMessage = nil
        if food.calories == nil {
            saveErrorMessage = Self.nilCaloriesMessage
        }
    }

    @discardableResult
    func save() -> Bool {
        saveErrorMessage = nil
        guard let selectedFood else {
            saveErrorMessage = "Pick a food from the search results first."
            return false
        }
        guard let caloriesDouble = selectedFood.calories else {
            saveErrorMessage = Self.nilCaloriesMessage
            return false
        }
        let calories = Int(caloriesDouble.rounded())
        guard calories >= 0 else {
            saveErrorMessage = Self.nilCaloriesMessage
            return false
        }
        let serving = servingLabel
        guard !serving.isEmpty else {
            saveErrorMessage = "Enter a serving (for example, “1 cup rice”) so we know what to log."
            return false
        }

        do {
            _ = try foodLogsStore.insert(
                foodName: selectedFood.name,
                serving: serving,
                calories: calories,
                meal: meal,
                loggedDate: loggedDate,
                macros: FoodLogMacrosJSON(from: selectedFood),
                mealdbRecipeId: mealdbRecipeId,
                nutritionFoodId: selectedFood.id
            )
            didSave = true
            return true
        } catch {
            saveErrorMessage = "We couldn't save that log. Please try again."
            return false
        }
    }

    /// Seeds an initial search when opened from recipe detail.
    func prepareInitialSearchIfNeeded() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, searchState == .idle, results.isEmpty else { return }
        onSearchQueryChanged()
    }

    // MARK: - Private

    private func performSearch() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            results = []
            searchState = .idle
            return
        }

        guard reachability.isOnline else {
            results = []
            searchState = .offline
            return
        }

        do {
            let foods = try await nutritionClient.searchFoods(query: query)
            guard !Task.isCancelled else { return }
            results = foods
            if foods.isEmpty {
                searchState = .empty
            } else {
                searchState = .results
            }
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            if let nutritionError = error as? NutritionClientError {
                switch nutritionError {
                case .transport:
                    searchState = .offline
                default:
                    searchState = .error(nutritionError.errorDescription ?? "Search failed.")
                }
            } else {
                let message = (error as? LocalizedError)?.errorDescription
                    ?? "We couldn't search foods right now. Check your connection and try again."
                searchState = .error(message)
            }
        }
    }
}
