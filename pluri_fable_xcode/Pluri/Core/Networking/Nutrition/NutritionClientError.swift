import Foundation

/// Typed errors surfaced by `NutritionClient` implementations.
enum NutritionClientError: Error, LocalizedError, Equatable, Sendable {
    case invalidRequest
    case invalidResponse
    case unauthorized
    case rateLimited
    case decodingFailed(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidRequest, .invalidResponse:
            "We couldn't look up that food right now."
        case .unauthorized:
            "The nutrition service rejected our connection. Please try again later."
        case .rateLimited:
            "We've made too many nutrition lookups — please try again in a moment."
        case .decodingFailed:
            "The nutrition service sent back something we didn't expect."
        case .transport:
            "We couldn't reach the nutrition service. Check your connection and try again."
        }
    }
}
