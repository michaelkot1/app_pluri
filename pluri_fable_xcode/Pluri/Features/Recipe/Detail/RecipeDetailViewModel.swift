import Foundation
import Observation
import SwiftData

/// Recipe detail logic (M7-09/12): lookup when incomplete, favorite toggle,
/// honest offline/error, Log sheet presentation with recipe prefill.
@MainActor
@Observable
final class RecipeDetailViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case offline
        case error(String)
    }

    private(set) var recipe: MealDBRecipe?
    private(set) var loadState: LoadState = .idle
    private(set) var isFavorite = false
    /// Presents the shared food logging sheet (M7-12).
    private(set) var isPresentingLogSheet = false

    private let mealID: String
    private let mealDBClient: any MealDBClient
    private let favoritesStore: RecipeFavoritesStore?
    private let reachability: any NetworkReachability
    private let seedRecipe: MealDBRecipe?
    private let loggedDate: Date
    private let initialMeal: FoodLogMeal

    init(
        mealID: String,
        mealDBClient: any MealDBClient,
        modelContext: ModelContext,
        userId: UUID?,
        syncEngine: (any SyncEngine)? = nil,
        seedRecipe: MealDBRecipe? = nil,
        reachability: (any NetworkReachability)? = nil,
        loggedDate: Date = .now,
        initialMeal: FoodLogMeal = .snack
    ) {
        self.mealID = mealID
        self.mealDBClient = mealDBClient
        self.seedRecipe = seedRecipe
        self.loggedDate = loggedDate
        self.initialMeal = initialMeal
        self.reachability = reachability ?? PathMonitorReachability()
        if let userId {
            self.favoritesStore = RecipeFavoritesStore(
                modelContext: modelContext,
                userId: userId,
                syncEngine: syncEngine
            )
        } else {
            self.favoritesStore = nil
        }
        self.reachability.start()
    }

    /// Prefill context for the shared Log sheet when a recipe is loaded.
    var foodLoggingContext: FoodLoggingContext? {
        guard let recipe else { return nil }
        return .fromRecipe(recipe, loggedDate: loggedDate, meal: initialMeal)
    }

    func load() async {
        loadState = .loading

        if let seed = seedRecipe, seed.id == mealID, isComplete(seed) {
            recipe = seed
            refreshFavorite()
            loadState = .loaded
            return
        }

        if let seed = seedRecipe, seed.id == mealID {
            recipe = seed
            refreshFavorite()
        }

        guard reachability.isOnline else {
            if let recipe, isComplete(recipe) {
                loadState = .loaded
            } else if recipe != nil {
                loadState = .loaded
            } else {
                loadState = .offline
            }
            return
        }

        do {
            let full = try await mealDBClient.lookupMeal(id: mealID)
            recipe = full
            refreshFavorite()
            loadState = .loaded
        } catch {
            if recipe != nil {
                loadState = .loaded
            } else {
                let message = (error as? LocalizedError)?.errorDescription
                    ?? "We couldn't load this recipe. Check your connection and try again."
                loadState = .error(message)
            }
        }
    }

    func toggleFavorite() {
        guard let recipe, let favoritesStore else { return }
        do {
            isFavorite = try favoritesStore.toggle(recipe: recipe)
        } catch {
            // Local write failure — leave UI state unchanged; never block.
        }
    }

    func openLog() {
        guard recipe != nil else { return }
        isPresentingLogSheet = true
    }

    func dismissLog() {
        isPresentingLogSheet = false
    }

    private func refreshFavorite() {
        guard let favoritesStore else {
            isFavorite = false
            return
        }
        isFavorite = (try? favoritesStore.isFavorite(id: mealID)) ?? false
    }

    private func isComplete(_ recipe: MealDBRecipe) -> Bool {
        !(recipe.instructions ?? "").isEmpty && !recipe.ingredients.isEmpty
    }
}
