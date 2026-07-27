import Foundation

/// Pure day-suggestions engine (M7-06 / SPEC §12 / §14 #67).
///
/// Produces ~3 allergy-safe options per `MealSlot` for a calendar day.
/// Deterministic given seed + inputs (FNV-1a over `userID|yyyy-MM-dd|mealSlot`,
/// SplitMix64 via `SeededGenerator`). Soft maintenance-calorie bias when kcal
/// is known; unknown kcal stays **neutral** (never invented). Favorites bias
/// via cuisine (`strArea`) + ingredient overlap after the allergy hard-filter.
///
/// `nonisolated` so it stays portable and unit-testable off the main actor
/// (PlanEngine / ScoreEngine spirit).
nonisolated enum RecipeSuggestionEngine {

    // MARK: Tunable constants (SPEC §14 #67 — owner-retunable)

    /// Options returned per meal slot when the safe pool is large enough.
    static let optionsPerSlot = 3

    /// Main meals (breakfast / lunch / dinner): soft band as a fraction of
    /// daily `maintenance_calories`.
    static let mainMealBandLower = 0.25
    static let mainMealBandUpper = 0.35

    /// Dessert: lighter soft band (SPEC §14 #67b / #69).
    static let dessertBandLower = 0.08
    static let dessertBandUpper = 0.15

    /// Similarity: shared cuisine weight vs per-ingredient overlap.
    static let cuisineSimilarityWeight = 2.0
    static let ingredientOverlapWeight = 1.0

    /// After allergy filter, top-K by similarity get a selection boost.
    static let similarityTopK = 5

    /// Candidate pool size for seeded sampling (bias toward higher ranks).
    static let samplingPoolMultiplier = 3

    // MARK: Input / output

    /// Snapshot inputs for one day of suggestions.
    ///
    /// - `candidates` must be **full** recipes (ingredients present) so allergy
    ///   and similarity can run honestly.
    /// - `caloriesByRecipeID` is optional / external (MealDB has no kcal) —
    ///   never invent values here.
    /// - `favorites` are full recipes used only for similarity (empty = no bias).
    struct Input: Sendable {
        var userID: UUID
        var day: Date
        var allergies: [String]
        var maintenanceCalories: Int?
        var candidates: [MealDBRecipe]
        var favorites: [MealDBRecipe]
        /// Known kcal keyed by MealDB `id`. Missing → neutral rank for that recipe.
        var caloriesByRecipeID: [String: Int]
        var calendar: Calendar

        init(
            userID: UUID,
            day: Date,
            allergies: [String] = [],
            maintenanceCalories: Int? = nil,
            candidates: [MealDBRecipe],
            favorites: [MealDBRecipe] = [],
            caloriesByRecipeID: [String: Int] = [:],
            calendar: Calendar = .current
        ) {
            self.userID = userID
            self.day = day
            self.allergies = allergies
            self.maintenanceCalories = maintenanceCalories
            self.candidates = candidates
            self.favorites = favorites
            self.caloriesByRecipeID = caloriesByRecipeID
            self.calendar = calendar
        }
    }

    /// ~3 options per slot; empty arrays are honest (no unsafe fill).
    struct DaySuggestions: Sendable, Equatable {
        var breakfast: [MealDBRecipe]
        var lunch: [MealDBRecipe]
        var dinner: [MealDBRecipe]
        var dessert: [MealDBRecipe]

        subscript(slot: MealSlot) -> [MealDBRecipe] {
            switch slot {
            case .breakfast: breakfast
            case .lunch: lunch
            case .dinner: dinner
            case .dessert: dessert
            }
        }
    }

    // MARK: Public API

    /// Builds deterministic day suggestions for every `MealSlot`.
    static func suggestions(for input: Input) -> DaySuggestions {
        DaySuggestions(
            breakfast: suggestions(for: .breakfast, input: input),
            lunch: suggestions(for: .lunch, input: input),
            dinner: suggestions(for: .dinner, input: input),
            dessert: suggestions(for: .dessert, input: input)
        )
    }

    /// Slot-level suggestions (also used by tests).
    static func suggestions(for slot: MealSlot, input: Input) -> [MealDBRecipe] {
        let ranked = rankedCandidates(for: slot, input: input)
        guard !ranked.isEmpty else { return [] }

        let seed = deterministicSeed(
            userID: input.userID,
            day: input.day,
            slot: slot,
            calendar: input.calendar
        )
        return sample(from: ranked, count: optionsPerSlot, seed: seed)
    }

    /// Allergy-filtered candidates for a slot, ordered by similarity boost then
    /// soft kcal fit (highest first). Exposed for unit tests of soft ranking.
    static func rankedCandidates(for slot: MealSlot, input: Input) -> [MealDBRecipe] {
        let pool = candidates(for: slot, from: input.candidates)
        let safe = pool.filter { !containsAllergen(recipe: $0, allergies: input.allergies) }
        guard !safe.isEmpty else { return [] }

        let similarity = similarityScores(candidates: safe, favorites: input.favorites)
        let boostedIDs = Set(
            similarity
                .sorted { lhs, rhs in
                    if lhs.value != rhs.value { return lhs.value > rhs.value }
                    return lhs.key < rhs.key
                }
                .prefix(similarityTopK)
                .map(\.key)
        )

        return safe.sorted { lhs, rhs in
            let left = rankKey(
                recipe: lhs,
                slot: slot,
                input: input,
                similarity: similarity[lhs.id] ?? 0,
                isBoosted: boostedIDs.contains(lhs.id)
            )
            let right = rankKey(
                recipe: rhs,
                slot: slot,
                input: input,
                similarity: similarity[rhs.id] ?? 0,
                isBoosted: boostedIDs.contains(rhs.id)
            )
            if left != right { return left > right }
            return lhs.id < rhs.id
        }
    }

    /// FNV-1a over `userID|yyyy-MM-dd|mealSlot` (SPEC §14 #67a / PlanInput spirit).
    static func deterministicSeed(
        userID: UUID,
        day: Date,
        slot: MealSlot,
        calendar: Calendar = .current
    ) -> UInt64 {
        let dayKey = dayString(day, calendar: calendar)
        let canonical = "\(userID.uuidString.lowercased())|\(dayKey)|\(slot.rawValue)"
        return fnv1a(canonical)
    }

    // MARK: Slot pooling (interim — SPEC §14 #69)

    /// Breakfast / Dessert from MealDB `strCategory`; lunch / dinner from the
    /// remaining non-breakfast/non-dessert pool (shared).
    static func candidates(for slot: MealSlot, from all: [MealDBRecipe]) -> [MealDBRecipe] {
        switch slot {
        case .breakfast:
            return all.filter { categoryMatches($0.category, needle: "Breakfast") }
        case .dessert:
            return all.filter { categoryMatches($0.category, needle: "Dessert") }
        case .lunch, .dinner:
            return all.filter { recipe in
                !categoryMatches(recipe.category, needle: "Breakfast")
                    && !categoryMatches(recipe.category, needle: "Dessert")
            }
        }
    }

    // MARK: Allergy hard-filter (SPEC §14 #67c)

    /// `true` when any ingredient name matches a profile allergy token.
    static func containsAllergen(recipe: MealDBRecipe, allergies: [String]) -> Bool {
        let tokens = allergyTokens(from: allergies)
        guard !tokens.isEmpty else { return false }
        let haystacks = recipe.ingredients.map { $0.name.lowercased() }
        for token in tokens {
            for haystack in haystacks where haystack.localizedStandardContains(token) {
                return true
            }
        }
        return false
    }

    /// Expands Q12 / `AllergenCatalog` labels (+ customs) into lowercase match tokens.
    static func allergyTokens(from allergies: [String]) -> Set<String> {
        var tokens: Set<String> = []
        for raw in allergies {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if let synonyms = allergenSynonyms[trimmed] {
                tokens.formUnion(synonyms)
            } else {
                // Custom / unmapped: split on "/" and whitespace-ish separators.
                for piece in trimmed.lowercased().split(whereSeparator: { $0 == "/" || $0 == "," }) {
                    let token = piece.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !token.isEmpty { tokens.insert(token) }
                }
            }
        }
        return tokens
    }

    /// Small synonym map for common Q12 chips vs MealDB ingredient phrasing.
    /// Unlisted customs fall back to the label text itself (#69).
    static let allergenSynonyms: [String: Set<String>] = [
        "Peanuts": ["peanut", "peanuts"],
        "Tree nuts": [
            "almond", "walnut", "cashew", "pecan", "hazelnut", "pistachio",
            "macadamia", "tree nut", "tree nuts",
        ],
        "Milk/dairy": [
            "milk", "dairy", "cheese", "butter", "cream", "yogurt", "yoghurt",
            "whey", "casein",
        ],
        "Eggs": ["egg", "eggs"],
        "Wheat/gluten": ["wheat", "gluten", "flour"],
        "Soy": ["soy", "soya", "tofu", "edamame"],
        "Fish": ["fish", "salmon", "tuna", "cod", "haddock", "anchovy"],
        "Shellfish": ["shrimp", "prawn", "crab", "lobster", "shellfish", "scallop"],
        "Sesame": ["sesame"],
    ]

    // MARK: Similarity (SPEC §14 #67d)

    static func similarityScores(
        candidates: [MealDBRecipe],
        favorites: [MealDBRecipe]
    ) -> [String: Double] {
        guard !favorites.isEmpty else {
            return Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, 0) })
        }
        let favoriteAreas = Set(favorites.compactMap { $0.area?.lowercased() })
        var favoriteIngredients: Set<String> = []
        for favorite in favorites {
            for ingredient in favorite.ingredients {
                let name = ingredient.name.lowercased()
                if !name.isEmpty { favoriteIngredients.insert(name) }
            }
        }

        var scores: [String: Double] = [:]
        for recipe in candidates {
            var score = 0.0
            if let area = recipe.area?.lowercased(), favoriteAreas.contains(area) {
                score += cuisineSimilarityWeight
            }
            for ingredient in recipe.ingredients {
                let name = ingredient.name.lowercased()
                if favoriteIngredients.contains(name) {
                    score += ingredientOverlapWeight
                } else if favoriteIngredients.contains(where: {
                    $0.localizedStandardContains(name) || name.localizedStandardContains($0)
                }) {
                    score += ingredientOverlapWeight * 0.5
                }
            }
            scores[recipe.id] = score
        }
        return scores
    }

    // MARK: Private helpers

    private struct RankKey: Comparable {
        var boosted: Bool
        var similarity: Double
        var kcalScore: Double
        var id: String

        static func < (lhs: RankKey, rhs: RankKey) -> Bool {
            if lhs.boosted != rhs.boosted { return !lhs.boosted && rhs.boosted }
            if lhs.similarity != rhs.similarity { return lhs.similarity < rhs.similarity }
            if lhs.kcalScore != rhs.kcalScore { return lhs.kcalScore < rhs.kcalScore }
            return lhs.id < rhs.id
        }
    }

    private static func rankKey(
        recipe: MealDBRecipe,
        slot: MealSlot,
        input: Input,
        similarity: Double,
        isBoosted: Bool
    ) -> RankKey {
        RankKey(
            boosted: isBoosted && similarity > 0,
            similarity: similarity,
            kcalScore: calorieScore(recipeID: recipe.id, slot: slot, input: input),
            id: recipe.id
        )
    }

    /// Soft kcal fit. `0` when maintenance or recipe kcal unknown (neutral).
    private static func calorieScore(recipeID: String, slot: MealSlot, input: Input) -> Double {
        guard let maintenance = input.maintenanceCalories, maintenance > 0 else { return 0 }
        guard let kcal = input.caloriesByRecipeID[recipeID], kcal > 0 else { return 0 }

        let band = calorieBand(for: slot, maintenance: maintenance)
        let kcalValue = Double(kcal)
        if kcalValue >= band.lower && kcalValue <= band.upper {
            return 2.0
        }
        let mid = (band.lower + band.upper) / 2
        let distance = abs(kcalValue - mid)
        let scale = max(mid, 1)
        return max(-1.0, 1.0 - distance / scale)
    }

    private static func calorieBand(
        for slot: MealSlot,
        maintenance: Int
    ) -> (lower: Double, upper: Double) {
        let fraction: (lower: Double, upper: Double) = switch slot {
        case .dessert: (dessertBandLower, dessertBandUpper)
        case .breakfast, .lunch, .dinner: (mainMealBandLower, mainMealBandUpper)
        }
        return (
            Double(maintenance) * fraction.lower,
            Double(maintenance) * fraction.upper
        )
    }

    private static func sample(
        from ranked: [MealDBRecipe],
        count: Int,
        seed: UInt64
    ) -> [MealDBRecipe] {
        guard !ranked.isEmpty else { return [] }
        if ranked.count <= count { return ranked }

        let poolSize = min(ranked.count, max(count * samplingPoolMultiplier, similarityTopK))
        var pool = Array(ranked.prefix(poolSize))
        var generator = SeededGenerator(seed: seed)

        // Partial Fisher–Yates, then take the first `count`.
        for i in 0..<min(count, pool.count) {
            let j = i + Int(generator.next() % UInt64(pool.count - i))
            pool.swapAt(i, j)
        }
        return Array(pool.prefix(count)).sorted { $0.id < $1.id }
    }

    private static func categoryMatches(_ category: String?, needle: String) -> Bool {
        guard let category else { return false }
        return category.localizedStandardContains(needle)
    }

    private static func dayString(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let dayValue = parts.day ?? 0
        return "\(year)-\(pad2(month))-\(pad2(dayValue))"
    }

    private static func pad2(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}
