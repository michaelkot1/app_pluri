import Foundation
import Testing
@testable import Pluri

@Suite("MealDB client")
struct MealDBClientTests {

    // MARK: - JSON decoding (M7-03/04 contract)

    @Test("Decodes full lookup meal with packed ingredients and tags")
    func decodesFullMeal() throws {
        let json = """
        {
          "meals": [
            {
              "idMeal": "52772",
              "strMeal": "Teriyaki Chicken Casserole",
              "strCategory": "Chicken",
              "strArea": "Japanese",
              "strCountry": "Japan",
              "strInstructions": "Preheat oven to 350 F.",
              "strMealThumb": "https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg",
              "strTags": "Meat,Casserole",
              "strYoutube": "https://www.youtube.com/watch?v=4aZr5hZXP_s",
              "strIngredient1": "soy sauce",
              "strIngredient2": "chicken breasts",
              "strIngredient3": "",
              "strIngredient4": null,
              "strMeasure1": "3/4 cup",
              "strMeasure2": "2",
              "strMeasure3": "",
              "strMeasure4": null
            }
          ]
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(MealDBMealsEnvelope.self, from: json)
        let recipe = try #require(envelope.meals?.first?.asDomainRecipe)

        #expect(recipe.id == "52772")
        #expect(recipe.name == "Teriyaki Chicken Casserole")
        #expect(recipe.category == "Chicken")
        #expect(recipe.area == "Japanese")
        #expect(recipe.country == "Japan")
        #expect(recipe.tags == ["Meat", "Casserole"])
        #expect(recipe.ingredients.count == 2)
        #expect(recipe.ingredients[0].name == "soy sauce")
        #expect(recipe.ingredients[0].measure == "3/4 cup")
        #expect(recipe.thumbnailURL?.absoluteString.contains("wvpsxx1468256321") == true)
    }

    @Test("Decodes filter summary and null meals as empty")
    func decodesFilterSummaryAndNullMeals() throws {
        let summaryJSON = """
        {
          "meals": [
            {
              "strMeal": "Chicken Alfredo Primavera",
              "strMealThumb": "https://www.themealdb.com/images/media/meals/syqypv1486981727.jpg",
              "idMeal": "52796",
              "strArea": "Italian",
              "strCountry": "Italy"
            }
          ]
        }
        """.data(using: .utf8)!

        let summary = try JSONDecoder().decode(MealDBMealsEnvelope.self, from: summaryJSON)
        let recipe = try #require(summary.meals?.first?.asDomainRecipe)
        #expect(recipe.id == "52796")
        #expect(recipe.area == "Italian")
        #expect(recipe.ingredients.isEmpty)
        #expect(recipe.instructions == nil)

        let emptyJSON = #"{"meals":null}"#.data(using: .utf8)!
        let empty = try JSONDecoder().decode(MealDBMealsEnvelope.self, from: emptyJSON)
        #expect(empty.meals == nil)
    }

    // MARK: - Mock path (offline)

    @Test("Mock filters by area, category, ingredient, and lookup")
    func mockFilterAndLookup() async throws {
        let client = MockMealDBClient()

        let italian = try await client.filterByArea("Italian")
        #expect(italian.map(\.id).sorted() == ["52771", "52794"])

        let chicken = try await client.filterByCategory("Chicken")
        #expect(chicken.map(\.id) == ["52772"])

        let soy = try await client.filterByIngredient("soy")
        #expect(soy.map(\.id) == ["52772"])

        let lookup = try await client.lookupMeal(id: "52771")
        #expect(lookup.name == "Spicy Arrabiata Penne")

        let search = try await client.searchMeals(name: "teriyaki")
        #expect(search.map(\.id) == ["52772"])
    }

    @Test("Mock lookup surfaces notFound for unknown id")
    func mockLookupNotFound() async {
        let client = MockMealDBClient()
        do {
            _ = try await client.lookupMeal(id: "999999")
            Issue.record("Expected notFound")
        } catch let error as MealDBClientError {
            #expect(error == .notFound)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Mock surfaces typed rateLimited error")
    func mockThrowsRateLimited() async {
        let client = MockMealDBClient(errorToThrow: .rateLimited)
        do {
            _ = try await client.searchMeals(name: "chicken")
            Issue.record("Expected rateLimited")
        } catch let error as MealDBClientError {
            #expect(error == .rateLimited)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Mock lists derive areas, categories, and ingredients from fixtures")
    func mockLists() async throws {
        let client = MockMealDBClient()
        let areas = try await client.listAreas()
        #expect(areas.contains("Italian"))
        #expect(areas.contains("Japanese"))

        let categories = try await client.listCategories()
        #expect(categories.contains("Vegan"))
        #expect(categories.contains("Pork"))

        let ingredients = try await client.listIngredients()
        #expect(ingredients.contains("chicken breasts"))
    }
}
