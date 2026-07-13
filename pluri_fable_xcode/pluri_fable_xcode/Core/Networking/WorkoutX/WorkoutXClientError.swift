import Foundation

/// Typed errors surfaced by `WorkoutXClient` implementations.
enum WorkoutXClientError: Error, LocalizedError, Sendable {
    case invalidRequest
    case invalidResponse
    case unauthorized
    case notFound
    case rateLimited
    case decodingFailed(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidRequest, .invalidResponse:
            "We couldn't reach the exercise library right now."
        case .unauthorized:
            "The exercise library rejected our connection. Please try again later."
        case .notFound:
            "That exercise couldn't be found."
        case .rateLimited:
            "We've made too many requests to the exercise library — please try again in a moment."
        case .decodingFailed:
            "The exercise library sent back something we didn't expect."
        case .transport:
            "We couldn't reach the exercise library. Check your connection and try again."
        }
    }
}
