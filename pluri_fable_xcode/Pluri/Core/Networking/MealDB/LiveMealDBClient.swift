import Foundation
import os.log

/// `URLSession`-backed `MealDBClient` for TheMealDB's free test key `1`
/// (keyless for Pluri — no secret in the bundle). See
/// `Core/Networking/MealDB/README.md`.
struct LiveMealDBClient: MealDBClient {
    private let session: URLSession
    private let baseURL: URL
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "MealDBClient")

    /// Default base includes the public test API key path segment `1`.
    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://www.themealdb.com/api/json/v1/1")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func searchMeals(name: String) async throws -> [MealDBRecipe] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let envelope: MealDBMealsEnvelope = try await perform(
            path: "search.php",
            queryItems: [URLQueryItem(name: "s", value: trimmed)]
        )
        return (envelope.meals ?? []).map(\.asDomainRecipe)
    }

    func lookupMeal(id: String) async throws -> MealDBRecipe {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MealDBClientError.invalidRequest }
        let envelope: MealDBMealsEnvelope = try await perform(
            path: "lookup.php",
            queryItems: [URLQueryItem(name: "i", value: trimmed)]
        )
        guard let meal = envelope.meals?.first else {
            throw MealDBClientError.notFound
        }
        return meal.asDomainRecipe
    }

    func filterByArea(_ area: String) async throws -> [MealDBRecipe] {
        try await filter(queryName: "a", value: area)
    }

    func filterByIngredient(_ ingredient: String) async throws -> [MealDBRecipe] {
        try await filter(queryName: "i", value: ingredient)
    }

    func filterByCategory(_ category: String) async throws -> [MealDBRecipe] {
        try await filter(queryName: "c", value: category)
    }

    func listAreas() async throws -> [String] {
        try await list(queryName: "a") { $0.strArea }
    }

    func listIngredients() async throws -> [String] {
        try await list(queryName: "i") { $0.strIngredient }
    }

    func listCategories() async throws -> [String] {
        try await list(queryName: "c") { $0.strCategory }
    }

    private func filter(queryName: String, value: String) async throws -> [MealDBRecipe] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let envelope: MealDBMealsEnvelope = try await perform(
            path: "filter.php",
            queryItems: [URLQueryItem(name: queryName, value: trimmed)]
        )
        return (envelope.meals ?? []).map(\.asDomainRecipe)
    }

    private func list(
        queryName: String,
        extract: (MealDBNamedListDTO) -> String?
    ) async throws -> [String] {
        // list.php reuses the `meals` key with sparse named rows; decode via
        // a dedicated envelope so we don't force meal fields.
        let data = try await rawData(
            path: "list.php",
            queryItems: [URLQueryItem(name: queryName, value: "list")]
        )
        let listEnvelope = try decodeListEnvelope(data)
        return (listEnvelope.meals ?? []).compactMap { row in
            extract(row)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
    }

    private func perform<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]
    ) async throws -> T {
        let data = try await rawData(path: path, queryItems: queryItems)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.error("MealDB decoding failed: \(error.localizedDescription)")
            throw MealDBClientError.decodingFailed(error.localizedDescription)
        }
    }

    private func rawData(path: String, queryItems: [URLQueryItem]) async throws -> Data {
        guard var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        ) else {
            throw MealDBClientError.invalidRequest
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw MealDBClientError.invalidRequest
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            logger.error("MealDB request failed: \(error.localizedDescription)")
            throw MealDBClientError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MealDBClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return data
        case 404:
            throw MealDBClientError.notFound
        case 429:
            throw MealDBClientError.rateLimited
        default:
            throw MealDBClientError.transport("Unexpected status code \(httpResponse.statusCode)")
        }
    }

    private func decodeListEnvelope(_ data: Data) throws -> MealDBNamedListEnvelope {
        do {
            return try JSONDecoder().decode(MealDBNamedListEnvelope.self, from: data)
        } catch {
            logger.error("MealDB list decoding failed: \(error.localizedDescription)")
            throw MealDBClientError.decodingFailed(error.localizedDescription)
        }
    }
}

/// Envelope for `list.php` rows (sparse objects under `meals`).
private struct MealDBNamedListEnvelope: Decodable, Sendable {
    let meals: [MealDBNamedListDTO]?
}
