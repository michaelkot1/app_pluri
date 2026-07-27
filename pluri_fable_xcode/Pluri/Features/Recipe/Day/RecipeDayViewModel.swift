import Foundation
import Observation
import SwiftData

/// Recipe Day screen logic (M7-08 / SPEC §12): calendar day selection, candidate
/// load, suggestion engine, offline cache honesty.
@MainActor
@Observable
final class RecipeDayViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case offlineCached
        case offlineNoCache
        case error(String)
    }

    private(set) var selectedDay: Date?
    private(set) var suggestions = RecipeSuggestionEngine.DaySuggestions(
        breakfast: [],
        lunch: [],
        dinner: [],
        dessert: []
    )
    private(set) var loadState: LoadState = .idle
    /// True when showing saved suggestions while offline / after network fail.
    private(set) var isShowingCachedSuggestions = false

    private let mealDBClient: any MealDBClient
    private let planStore: PlanStore
    private let cache: RecipeSuggestionsCache
    private let favoritesStore: RecipeFavoritesStore?
    private let reachability: any NetworkReachability
    private let calendar: Calendar
    private let userId: UUID

    private var loadTask: Task<Void, Never>?
    private var inMemoryPool: [MealDBRecipe] = []

    init(
        mealDBClient: any MealDBClient,
        planStore: PlanStore,
        modelContext: ModelContext,
        userId: UUID,
        syncEngine: (any SyncEngine)? = nil,
        reachability: (any NetworkReachability)? = nil,
        calendar: Calendar = .current
    ) {
        self.mealDBClient = mealDBClient
        self.planStore = planStore
        self.userId = userId
        self.calendar = calendar
        self.cache = RecipeSuggestionsCache(
            modelContext: modelContext,
            userId: userId,
            calendar: calendar
        )
        self.favoritesStore = RecipeFavoritesStore(
            modelContext: modelContext,
            userId: userId,
            syncEngine: syncEngine
        )
        self.reachability = reachability ?? PathMonitorReachability()
        self.reachability.start()
    }

    // MARK: - Day selection

    func select(day: Date) {
        selectedDay = calendar.startOfDay(for: day)
        reload()
    }

    func resolvedSelectedDay(today: Date = .now) -> Date {
        selectedDay ?? calendar.startOfDay(for: today)
    }

    func monthDays(containing date: Date) -> [Date] {
        guard let month = calendar.dateInterval(of: .month, for: date) else {
            return [calendar.startOfDay(for: date)]
        }
        var days: [Date] = []
        var cursor = month.start
        while cursor < month.end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    // MARK: - Load

    func reload() {
        loadTask?.cancel()
        let day = resolvedSelectedDay()
        loadTask = Task { await loadSuggestions(for: day) }
    }

    func loadSuggestions(for day: Date) async {
        let dayStart = calendar.startOfDay(for: day)
        loadState = .loading
        isShowingCachedSuggestions = false

        let online = reachability.isOnline

        if !online {
            if let cached = try? cache.loadDaySuggestions(for: dayStart) {
                suggestions = cached
                isShowingCachedSuggestions = true
                loadState = allSlotsEmpty(cached) ? .empty : .offlineCached
            } else {
                suggestions = emptySuggestions
                loadState = .offlineNoCache
            }
            return
        }

        do {
            let pool = try await ensureCandidatePool()
            let favorites = favoriteRecipes(matching: pool)
            let allergies = Array(planStore.profile?.allergies ?? [])
            let input = RecipeSuggestionEngine.Input(
                userID: userId,
                day: dayStart,
                allergies: allergies,
                maintenanceCalories: planStore.profile?.maintenanceCalories,
                candidates: pool,
                favorites: favorites,
                caloriesByRecipeID: [:],
                calendar: calendar
            )
            let result = RecipeSuggestionEngine.suggestions(for: input)
            suggestions = result
            try? cache.saveDaySuggestions(result, for: dayStart)

            if allSlotsEmpty(result) {
                loadState = .empty
            } else {
                loadState = .loaded
            }
        } catch {
            if let cached = try? cache.loadDaySuggestions(for: dayStart) {
                suggestions = cached
                isShowingCachedSuggestions = true
                loadState = allSlotsEmpty(cached) ? .empty : .offlineCached
            } else {
                suggestions = emptySuggestions
                let message = (error as? LocalizedError)?.errorDescription
                    ?? "We couldn't load recipes right now. Check your connection and try again."
                loadState = .error(message)
            }
        }
    }

    // MARK: - Private

    private var emptySuggestions: RecipeSuggestionEngine.DaySuggestions {
        RecipeSuggestionEngine.DaySuggestions(
            breakfast: [],
            lunch: [],
            dinner: [],
            dessert: []
        )
    }

    private func allSlotsEmpty(_ suggestions: RecipeSuggestionEngine.DaySuggestions) -> Bool {
        MealSlot.allCases.allSatisfy { suggestions[$0].isEmpty }
    }

    private func ensureCandidatePool() async throws -> [MealDBRecipe] {
        if !inMemoryPool.isEmpty {
            return inMemoryPool
        }

        if let cached = try? cache.loadCandidatePool(),
           cache.isCandidatePoolFresh(cached.updatedAt),
           !cached.recipes.isEmpty {
            inMemoryPool = cached.recipes
            return cached.recipes
        }

        let pool = try await RecipeCandidateLoader.loadPool(using: mealDBClient)
        inMemoryPool = pool
        try? cache.saveCandidatePool(pool)
        return pool
    }

    /// Favorites resolved against the candidate pool (full recipes for similarity).
    private func favoriteRecipes(matching pool: [MealDBRecipe]) -> [MealDBRecipe] {
        guard let favoritesStore else { return [] }
        let favoriteIDs: Set<String>
        do {
            favoriteIDs = Set(try favoritesStore.allFavorites().map(\.mealdbRecipeId))
        } catch {
            return []
        }
        guard !favoriteIDs.isEmpty else { return [] }
        return pool.filter { favoriteIDs.contains($0.id) }
    }
}
