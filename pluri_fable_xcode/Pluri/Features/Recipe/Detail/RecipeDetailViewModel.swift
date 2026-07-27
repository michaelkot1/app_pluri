import Foundation
import Observation
import SwiftData

/// Recipe detail logic (M7-09): lookup when incomplete, favorite toggle,
/// honest offline/error — Log is stub only until M7-11/12.
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
    /// Stub CTA — food logging lands in M7-11/12.
    private(set) var showsLogComingSoon = false

    private let mealID: String
    private let mealDBClient: any MealDBClient
    private let favoritesStore: RecipeFavoritesStore?
    private let reachability: any NetworkReachability
    private let seedRecipe: MealDBRecipe?

    init(
        mealID: String,
        mealDBClient: any MealDBClient,
        modelContext: ModelContext,
        userId: UUID?,
        syncEngine: (any SyncEngine)? = nil,
        seedRecipe: MealDBRecipe? = nil,
        reachability: (any NetworkReachability)? = nil
    ) {
        self.mealID = mealID
        self.mealDBClient = mealDBClient
        self.seedRecipe = seedRecipe
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

    func tapLogStub() {
        showsLogComingSoon = true
    }

    func dismissLogStub() {
        showsLogComingSoon = false
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
