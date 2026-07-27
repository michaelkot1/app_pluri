import Foundation
import Observation

/// Explore tab logic (M7-10 / SPEC §12): cuisine / protein network filters,
/// duration / portion client heuristics, honest offline / empty / error.
@MainActor
@Observable
final class RecipeExploreViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case offline
        case error(String)
    }

    var filters = RecipeExploreFilters()
    private(set) var results: [MealDBRecipe] = []
    private(set) var loadState: LoadState = .idle

    private let mealDBClient: any MealDBClient
    private let reachability: any NetworkReachability
    private var loadTask: Task<Void, Never>?

    /// Max summaries to hydrate via lookup when duration/portion filters need
    /// full recipes (instructions / measures).
    static let maxLookupsForHeuristics = 24

    init(
        mealDBClient: any MealDBClient,
        reachability: (any NetworkReachability)? = nil
    ) {
        self.mealDBClient = mealDBClient
        self.reachability = reachability ?? PathMonitorReachability()
        self.reachability.start()
    }

    func setCuisine(_ value: RecipeExploreCuisine) {
        filters.cuisine = value
        reload()
    }

    func setProtein(_ value: RecipeExploreProtein) {
        filters.protein = value
        reload()
    }

    func setDuration(_ value: RecipeExploreDuration) {
        filters.duration = value
        reload()
    }

    func setPortion(_ value: RecipeExplorePortion) {
        filters.portion = value
        reload()
    }

    func reload() {
        loadTask?.cancel()
        loadTask = Task { await search() }
    }

    func search() async {
        loadState = .loading

        guard reachability.isOnline else {
            results = []
            loadState = .offline
            return
        }

        do {
            var recipes = try await fetchBaseResults()
            let needsFullRecipes =
                filters.duration != .any || filters.portion != .any

            if needsFullRecipes {
                recipes = try await hydrateForHeuristics(recipes)
                recipes = recipes.filter {
                    RecipeExploreHeuristics.matchesDuration(filters.duration, recipe: $0)
                        && RecipeExploreHeuristics.matchesPortion(filters.portion, recipe: $0)
                }
            }

            results = recipes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            loadState = results.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            return
        } catch {
            results = []
            let message = (error as? LocalizedError)?.errorDescription
                ?? "We couldn't search recipes right now. Check your connection and try again."
            loadState = .error(message)
        }
    }

    // MARK: - Private

    private func fetchBaseResults() async throws -> [MealDBRecipe] {
        let area = filters.cuisine.mealDBArea
        let category = filters.protein.mealDBCategory

        switch (area, category) {
        case (nil, nil):
            // Default browse: light search seed so Explore isn't empty on open.
            return try await mealDBClient.searchMeals(name: "chicken")
        case (let area?, nil):
            return try await mealDBClient.filterByArea(area)
        case (nil, let category?):
            return try await mealDBClient.filterByCategory(category)
        case (let area?, let category?):
            let byArea = try await mealDBClient.filterByArea(area)
            let byCategoryIDs = Set(
                try await mealDBClient.filterByCategory(category).map(\.id)
            )
            return byArea.filter { byCategoryIDs.contains($0.id) }
        }
    }

    private func hydrateForHeuristics(_ summaries: [MealDBRecipe]) async throws -> [MealDBRecipe] {
        var full: [MealDBRecipe] = []
        for summary in summaries.prefix(Self.maxLookupsForHeuristics) {
            try Task.checkCancellation()
            if !summary.ingredients.isEmpty, !(summary.instructions ?? "").isEmpty {
                full.append(summary)
                continue
            }
            do {
                let recipe = try await mealDBClient.lookupMeal(id: summary.id)
                full.append(recipe)
            } catch {
                continue
            }
        }
        return full
    }
}
