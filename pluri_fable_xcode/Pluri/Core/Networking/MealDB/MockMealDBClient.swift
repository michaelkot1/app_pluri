import Foundation

/// Deterministic in-memory `MealDBClient` for previews and tests — no
/// network access.
struct MockMealDBClient: MealDBClient {
    let fixtures: [MealDBRecipe]

    init(fixtures: [MealDBRecipe] = .mealDBPreviewFixtures) {
        self.fixtures = fixtures
    }

    func searchMeals(name: String) async throws -> [MealDBRecipe] {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        return fixtures.filter { $0.name.localizedStandardContains(needle) }
    }

    func lookupMeal(id: String) async throws -> MealDBRecipe {
        guard let recipe = fixtures.first(where: { $0.id == id }) else {
            throw MealDBClientError.notFound
        }
        return recipe
    }

    func filterByArea(_ area: String) async throws -> [MealDBRecipe] {
        fixtures.filter { $0.area?.localizedStandardContains(area) == true }
    }

    func filterByIngredient(_ ingredient: String) async throws -> [MealDBRecipe] {
        fixtures.filter { recipe in
            recipe.ingredients.contains {
                $0.name.localizedStandardContains(ingredient)
            }
        }
    }

    func filterByCategory(_ category: String) async throws -> [MealDBRecipe] {
        fixtures.filter { $0.category?.localizedStandardContains(category) == true }
    }

    func listAreas() async throws -> [String] {
        Array(Set(fixtures.compactMap(\.area))).sorted()
    }

    func listIngredients() async throws -> [String] {
        Array(Set(fixtures.flatMap(\.ingredients).map(\.name))).sorted()
    }

    func listCategories() async throws -> [String] {
        Array(Set(fixtures.compactMap(\.category))).sorted()
    }
}

extension [MealDBRecipe] {
    /// Small deterministic fixture set spanning cuisines and protein categories
    /// for Explore / suggestion tests without hitting the network.
    static var mealDBPreviewFixtures: [MealDBRecipe] {
        [
            MealDBRecipe(
                id: "52771",
                name: "Spicy Arrabiata Penne",
                thumbnailURL: URL(string: "https://www.themealdb.com/images/media/meals/ustsqw1468250014.jpg"),
                category: "Vegetarian",
                area: "Italian",
                country: "Italy",
                instructions: "Bring a large pot of water to a boil. Add pasta and cook about 9 minutes. Make the sauce, combine, and serve warm.",
                tags: ["Pasta", "Curry"],
                youtubeURL: URL(string: "https://www.youtube.com/watch?v=1IszT_guI08"),
                sourceURL: nil,
                ingredients: [
                    MealDBIngredient(name: "penne rigate", measure: "1 pound"),
                    MealDBIngredient(name: "olive oil", measure: "1/4 cup"),
                    MealDBIngredient(name: "garlic", measure: "3 cloves"),
                    MealDBIngredient(name: "chopped tomatoes", measure: "1 tin"),
                ]
            ),
            MealDBRecipe(
                id: "52772",
                name: "Teriyaki Chicken Casserole",
                thumbnailURL: URL(string: "https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg"),
                category: "Chicken",
                area: "Japanese",
                country: "Japan",
                instructions: "Preheat oven to 350 F. Make teriyaki sauce. Bake chicken 35 minutes, shred, add vegetables and rice, bake 15 minutes more.",
                tags: ["Meat", "Casserole"],
                youtubeURL: URL(string: "https://www.youtube.com/watch?v=4aZr5hZXP_s"),
                sourceURL: nil,
                ingredients: [
                    MealDBIngredient(name: "soy sauce", measure: "3/4 cup"),
                    MealDBIngredient(name: "chicken breasts", measure: "2"),
                    MealDBIngredient(name: "brown rice", measure: "3 cups"),
                    MealDBIngredient(name: "stir-fry vegetables", measure: "1 (12 oz.)"),
                ]
            ),
            MealDBRecipe(
                id: "52874",
                name: "Beef and Mustard Pie",
                thumbnailURL: URL(string: "https://www.themealdb.com/images/media/meals/sytuqu1511553755.jpg"),
                category: "Beef",
                area: "British",
                country: "United Kingdom",
                instructions: "Preheat the oven. Brown the beef, simmer with mustard and stock for 45 minutes, top with pastry, bake until golden.",
                tags: ["Pie"],
                youtubeURL: nil,
                sourceURL: nil,
                ingredients: [
                    MealDBIngredient(name: "beef", measure: "1kg"),
                    MealDBIngredient(name: "mustard", measure: "2 tbs"),
                    MealDBIngredient(name: "puff pastry", measure: "320g"),
                ]
            ),
            MealDBRecipe(
                id: "52959",
                name: "Baked salmon with fennel & tomatoes",
                thumbnailURL: URL(string: "https://www.themealdb.com/images/media/meals/1548772327.jpg"),
                category: "Seafood",
                area: "British",
                country: "United Kingdom",
                instructions: "Heat oven. Arrange fennel and tomatoes, top with salmon, bake about 20 minutes.",
                tags: ["Fish", "Paleo"],
                youtubeURL: nil,
                sourceURL: nil,
                ingredients: [
                    MealDBIngredient(name: "salmon", measure: "2 fillets"),
                    MealDBIngredient(name: "fennel", measure: "1"),
                    MealDBIngredient(name: "cherry tomatoes", measure: "250g"),
                ]
            ),
            MealDBRecipe(
                id: "52794",
                name: "Vegan Lasagna",
                thumbnailURL: URL(string: "https://www.themealdb.com/images/media/meals/rvxxuy1468312893.jpg"),
                category: "Vegan",
                area: "Italian",
                country: "Italy",
                instructions: "Layer pasta with vegetable ragu and bake until bubbling, about 40 minutes.",
                tags: ["Vegetarian", "Pasta"],
                youtubeURL: nil,
                sourceURL: nil,
                ingredients: [
                    MealDBIngredient(name: "lasagna noodles", measure: "1 package"),
                    MealDBIngredient(name: "tomato sauce", measure: "2 cups"),
                    MealDBIngredient(name: "spinach", measure: "2 cups"),
                ]
            ),
            MealDBRecipe(
                id: "52995",
                name: "BBQ Pork Sloppy Joes",
                thumbnailURL: URL(string: "https://www.themealdb.com/images/media/meals/atd5sh1583188467.jpg"),
                category: "Pork",
                area: "United States",
                country: "United States",
                instructions: "Brown pork, simmer in BBQ sauce 15 minutes, serve on buns.",
                tags: ["Sandwich"],
                youtubeURL: nil,
                sourceURL: nil,
                ingredients: [
                    MealDBIngredient(name: "pork mince", measure: "500g"),
                    MealDBIngredient(name: "BBQ sauce", measure: "1 cup"),
                    MealDBIngredient(name: "burger buns", measure: "4"),
                ]
            ),
        ]
    }
}
