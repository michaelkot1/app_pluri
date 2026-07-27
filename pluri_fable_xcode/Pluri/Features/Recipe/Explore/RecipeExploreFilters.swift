import Foundation

/// Explore filter value sets (M7-10 / SPEC §12 / §14 #67e).
///
/// Duration and portion have **no** MealDB fields — client heuristics only
/// (see `RecipeExploreHeuristics` and MealDB README).

enum RecipeExploreCuisine: String, CaseIterable, Identifiable, Sendable, Hashable {
    case any
    case american
    case british
    case chinese
    case french
    case indian
    case italian
    case japanese
    case mexican
    case thai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: "Any"
        case .american: "American"
        case .british: "British"
        case .chinese: "Chinese"
        case .french: "French"
        case .indian: "Indian"
        case .italian: "Italian"
        case .japanese: "Japanese"
        case .mexican: "Mexican"
        case .thai: "Thai"
        }
    }

    /// Live filterable `strArea` values (MealDB README caveat — classic labels
    /// like American/French/Indian often need mapped country names).
    var mealDBArea: String? {
        switch self {
        case .any: nil
        case .american: "United States"
        case .british: "British"
        case .chinese: "Chinese"
        case .french: "France"
        case .indian: "India"
        case .italian: "Italian"
        case .japanese: "Japanese"
        case .mexican: "Mexican"
        case .thai: "Thai"
        }
    }
}

enum RecipeExploreProtein: String, CaseIterable, Identifiable, Sendable, Hashable {
    case any
    case chicken
    case beef
    case pork
    case seafood
    case vegetarian
    case vegan

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: "Any"
        case .chicken: "Chicken"
        case .beef: "Beef"
        case .pork: "Pork"
        case .seafood: "Seafood"
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        }
    }

    /// MealDB `strCategory` for `filter.php?c=` (#67e / README).
    var mealDBCategory: String? {
        switch self {
        case .any: nil
        case .chicken: "Chicken"
        case .beef: "Beef"
        case .pork: "Pork"
        case .seafood: "Seafood"
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        }
    }
}

enum RecipeExploreDuration: String, CaseIterable, Identifiable, Sendable, Hashable {
    case any
    case under20
    case from20to45
    case over45

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: "Any time"
        case .under20: "≤ 20 min"
        case .from20to45: "20–45 min"
        case .over45: "45+ min"
        }
    }
}

enum RecipeExplorePortion: String, CaseIterable, Identifiable, Sendable, Hashable {
    case any
    case single
    case mealPrep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: "Any portion"
        case .single: "Single"
        case .mealPrep: "Meal-prep"
        }
    }
}

/// Snapshot of Explore filter chips.
struct RecipeExploreFilters: Equatable, Sendable {
    var cuisine: RecipeExploreCuisine = .any
    var protein: RecipeExploreProtein = .any
    var duration: RecipeExploreDuration = .any
    var portion: RecipeExplorePortion = .any

    var hasActiveFilters: Bool {
        cuisine != .any || protein != .any || duration != .any || portion != .any
    }
}

/// Client-side duration / portion heuristics (M7-10) — MealDB has no cook-time
/// or servings fields on the free API.
nonisolated enum RecipeExploreHeuristics {

    /// Parses the largest minute mention in instructions (e.g. "35 minutes",
    /// "bake 20 min"). `nil` when no usable duration is found.
    static func estimatedMinutes(in instructions: String?) -> Int? {
        guard let instructions, !instructions.isEmpty else { return nil }
        let pattern = #"(\d+)\s*(?:-|–|to\s+\d+\s*)?(?:minutes?|mins?|min\.?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(instructions.startIndex..., in: instructions)
        let matches = regex.matches(in: instructions, options: [], range: range)
        var minutes: [Int] = []
        for match in matches {
            guard match.numberOfRanges >= 2,
                  let numberRange = Range(match.range(at: 1), in: instructions),
                  let value = Int(instructions[numberRange])
            else { continue }
            minutes.append(value)
        }
        return minutes.max()
    }

    static func matchesDuration(_ duration: RecipeExploreDuration, recipe: MealDBRecipe) -> Bool {
        guard duration != .any else { return true }
        guard let minutes = estimatedMinutes(in: recipe.instructions) else {
            // Unknown duration excluded when a duration filter is active (honest).
            return false
        }
        switch duration {
        case .any: return true
        case .under20: return minutes <= 20
        case .from20to45: return minutes > 20 && minutes <= 45
        case .over45: return minutes > 45
        }
    }

    /// Meal-prep signals: batch language, large measures, casserole tags.
    static func isMealPrep(_ recipe: MealDBRecipe) -> Bool {
        let haystacks: [String] = {
            var parts: [String] = []
            if let instructions = recipe.instructions { parts.append(instructions) }
            parts.append(contentsOf: recipe.tags)
            if let category = recipe.category { parts.append(category) }
            parts.append(contentsOf: recipe.ingredients.map(\.measure))
            parts.append(contentsOf: recipe.ingredients.map(\.name))
            return parts
        }()
        let text = haystacks.joined(separator: " ").lowercased()

        let batchPhrases = [
            "meal prep", "meal-prep", "batch", "freezer", "leftover",
            "casserole", "make ahead", "make-ahead", "feeds a crowd",
        ]
        if batchPhrases.contains(where: { text.localizedStandardContains($0) }) {
            return true
        }

        // Large measure heuristics (kg / pounds / dozen / multi-cup batches).
        let measurePattern = #"(\d+)\s*(kg|kilograms?|lbs?|pounds?|dozen)\b"#
        if let regex = try? NSRegularExpression(pattern: measurePattern, options: [.caseInsensitive]) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, options: [], range: range) {
                guard match.numberOfRanges >= 2,
                      let numberRange = Range(match.range(at: 1), in: text),
                      let value = Int(text[numberRange]),
                      value >= 1
                else { continue }
                return true
            }
        }

        return false
    }

    static func matchesPortion(_ portion: RecipeExplorePortion, recipe: MealDBRecipe) -> Bool {
        switch portion {
        case .any: true
        case .mealPrep: isMealPrep(recipe)
        case .single: !isMealPrep(recipe)
        }
    }
}
