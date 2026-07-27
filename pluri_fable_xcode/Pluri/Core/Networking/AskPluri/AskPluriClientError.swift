import Foundation

/// Typed errors surfaced by `AskPluriClient` for UI (#66d / #66e).
/// Never carry raw Gemini / quota dumps — only coach-facing copy.
enum AskPluriClientError: Error, LocalizedError, Equatable, Sendable {
    /// Network / offline / transport failure reaching Supabase Functions.
    case transport(String)
    /// Coach temporarily unavailable (Gemini busy / 5xx mapped by EF).
    case busy(String)
    /// App-side or Gemini rate limit (HTTP 429 / `throttled`).
    case throttled(String)
    /// Missing or invalid user JWT.
    case unauthorized
    /// Unexpected success/error JSON or non-mapped HTTP status.
    case invalidResponse

    static let defaultBusyMessage = "Your coach is busy — try again shortly."
    static let defaultThrottledMessage = "Your coach is busy — try again shortly."

    var errorDescription: String? {
        switch self {
        case let .transport(detail):
            detail.isEmpty
                ? "We couldn't reach your coach. Check your connection and try again."
                : detail
        case let .busy(message):
            message
        case let .throttled(message):
            message
        case .unauthorized:
            "Sign in to ask your coach."
        case .invalidResponse:
            "Your coach sent back something we didn't expect. Please try again."
        }
    }
}
