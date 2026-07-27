import Foundation
import Testing
@testable import Pluri

@Suite("Nutrition client")
struct NutritionClientTests {

    // MARK: - JSON decoding (M7-03/05 contract)

    @Test("Decodes numeric macros including calories and protein")
    func decodesNumericMacros() throws {
        let json = """
        [
          {
            "name": "apple",
            "calories": 95,
            "serving_size_g": 182.0,
            "fat_total_g": 0.3,
            "fat_saturated_g": 0.1,
            "protein_g": 0.5,
            "sodium_mg": 1,
            "potassium_mg": 20,
            "cholesterol_mg": 0,
            "carbohydrates_total_g": 25.6,
            "fiber_g": 4.3,
            "sugar_g": 18.8
          }
        ]
        """.data(using: .utf8)!

        let rows = try JSONDecoder().decode([NutritionFoodDTO].self, from: json)
        let food = try #require(rows.first?.asDomainFood)

        #expect(food.name == "apple")
        #expect(food.servingSizeGrams == 182)
        #expect(food.calories == 95)
        #expect(food.proteinGrams == 0.5)
        #expect(food.carbohydratesTotalGrams == 25.6)
        #expect(food.id == "apple|182.0")
    }

    @Test("Maps free-tier premium gate strings to nil calories and protein")
    func decodesPremiumGatedFieldsAsNil() throws {
        let json = """
        [
          {
            "name": "brisket",
            "calories": "Only available for premium subscribers.",
            "serving_size_g": 453.592,
            "fat_total_g": 82.9,
            "fat_saturated_g": 33.2,
            "protein_g": "Only available for premium subscribers.",
            "sodium_mg": 217,
            "potassium_mg": 781,
            "cholesterol_mg": 487,
            "carbohydrates_total_g": 0.0,
            "fiber_g": 0.0,
            "sugar_g": 0.0
          }
        ]
        """.data(using: .utf8)!

        let rows = try JSONDecoder().decode([NutritionFoodDTO].self, from: json)
        let food = try #require(rows.first?.asDomainFood)

        #expect(food.name == "brisket")
        #expect(food.calories == nil)
        #expect(food.proteinGrams == nil)
        #expect(food.fatTotalGrams == 82.9)
        #expect(food.servingSizeGrams == 453.592)
    }

    // MARK: - Mock path

    @Test("MockNutritionClient filters fixtures by query")
    func mockSearch() async throws {
        let client = MockNutritionClient()
        let apples = try await client.searchFoods(query: "apple")
        #expect(apples.map(\.name) == ["apple"])
        #expect(apples.first?.calories == 95)

        let empty = try await client.searchFoods(query: "   ")
        #expect(empty.isEmpty)
    }

    @Test("MockNutritionClient surfaces typed unauthorized error")
    func mockThrowsUnauthorized() async {
        let client = MockNutritionClient(errorToThrow: .unauthorized)
        do {
            _ = try await client.searchFoods(query: "apple")
            Issue.record("Expected unauthorized")
        } catch let error as NutritionClientError {
            #expect(error == .unauthorized)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("MockNutritionClient surfaces typed rateLimited error")
    func mockThrowsRateLimited() async {
        let client = MockNutritionClient(errorToThrow: .rateLimited)
        do {
            _ = try await client.searchFoods(query: "apple")
            Issue.record("Expected rateLimited")
        } catch let error as NutritionClientError {
            #expect(error == .rateLimited)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - No API key literals

    @Test("Secrets and Nutrition client sources never embed a literal API key")
    func noAPIKeyLiteralInClientOrSecrets() throws {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let projectRoot = testsDir.deletingLastPathComponent()

        let paths = [
            projectRoot.appending(path: "Pluri/Core/Secrets.swift"),
            projectRoot.appending(path: "Pluri/Core/Networking/Nutrition/NutritionClient.swift"),
            projectRoot.appending(path: "Pluri/Core/Networking/Nutrition/NutritionClientError.swift"),
            projectRoot.appending(path: "Pluri/Core/Networking/Nutrition/LiveNutritionClient.swift"),
            projectRoot.appending(path: "Pluri/Core/Networking/Nutrition/MockNutritionClient.swift"),
            projectRoot.appending(path: "Pluri/Core/Networking/Nutrition/NutritionFoodDTO.swift"),
            projectRoot.appending(path: "Pluri/Core/Networking/Nutrition/README.md"),
            projectRoot.appending(path: "Pluri/Core/Networking/MealDB/README.md"),
            projectRoot.appending(path: "Config/Info.plist"),
        ]

        for path in paths {
            let source = try String(contentsOf: path, encoding: .utf8)
            #expect(
                !source.contains("NUTRITION_API_KEY="),
                "\(path.lastPathComponent) must not assign NUTRITION_API_KEY inline"
            )
            // Pasted key values after the header name (docs may say `X-Api-Key: <key>`).
            #expect(
                source.range(
                    of: #"X-Api-Key:\s+[A-Za-z0-9_\-]{16,}"#,
                    options: .regularExpression
                ) == nil,
                "\(path.lastPathComponent) must not paste a real X-Api-Key value"
            )
        }

        let liveSource = try String(
            contentsOf: projectRoot.appending(path: "Pluri/Core/Networking/Nutrition/LiveNutritionClient.swift"),
            encoding: .utf8
        )
        #expect(liveSource.contains("Secrets.nutritionAPIKey"))
        #expect(liveSource.contains("X-Api-Key"))
        #expect(Bundle.main.object(forInfoDictionaryKey: "NUTRITION_API_KEY") is String)
    }
}
