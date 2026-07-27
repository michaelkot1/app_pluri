import Foundation

/// Typed errors surfaced by `MealDBClient` implementations.
enum MealDBClientError: Error, LocalizedError, Equatable, Sendable {
    case invalidRequest
    case invalidResponse
    case notFound
    case rateLimited
    case decodingFailed(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidRequest, .invalidResponse:
            "We couldn't reach the recipe library right now."
        case .notFound:
            "That recipe couldn't be found."
        case .rateLimited:
            "We've made too many requests to the recipe library — please try again in a moment."
        case .decodingFailed:
            "The recipe library sent back something we didn't expect."
        case .transport:
            "We couldn't reach the recipe library. Check your connection and try again."
        }
    }
}
