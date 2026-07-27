import Foundation
import os.log

/// `URLSession`-backed `NutritionClient` for API Ninjas Nutrition.
/// Authenticated with `X-Api-Key` from `Secrets.nutritionAPIKey`
/// (`NUTRITION_API_KEY` → xcconfig → Info.plist). See
/// `Core/Networking/Nutrition/README.md`.
struct LiveNutritionClient: NutritionClient {
    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "NutritionClient")

    /// Hardcoded API Ninjas v1 base unless a future spike proves otherwise.
    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.api-ninjas.com/v1")!,
        apiKey: String = Secrets.nutritionAPIKey
    ) {
        self.session = session
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    func searchFoods(query: String) async throws -> [NutritionFood] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard var components = URLComponents(
            url: baseURL.appending(path: "nutrition"),
            resolvingAgainstBaseURL: false
        ) else {
            throw NutritionClientError.invalidRequest
        }
        components.queryItems = [URLQueryItem(name: "query", value: trimmed)]
        guard let url = components.url else {
            throw NutritionClientError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("Nutrition request failed: \(error.localizedDescription)")
            throw NutritionClientError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NutritionClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 400, 401, 403:
            // Free-tier invalid key returns HTTP 400 `{"error":"Invalid API Key."}`.
            throw NutritionClientError.unauthorized
        case 429:
            throw NutritionClientError.rateLimited
        default:
            throw NutritionClientError.transport("Unexpected status code \(httpResponse.statusCode)")
        }

        do {
            let rows = try JSONDecoder().decode([NutritionFoodDTO].self, from: data)
            return rows.map(\.asDomainFood)
        } catch {
            logger.error("Nutrition decoding failed: \(error.localizedDescription)")
            throw NutritionClientError.decodingFailed(error.localizedDescription)
        }
    }
}
