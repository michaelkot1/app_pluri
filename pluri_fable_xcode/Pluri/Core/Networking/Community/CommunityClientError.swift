import Foundation

/// Typed errors surfaced by `CommunityClient` for UI (#72d).
/// Never invent feed content when offline / unauthorized — surface these instead.
enum CommunityClientError: Error, LocalizedError, Equatable, Sendable {
    /// Network / offline / transport failure reaching Supabase.
    case transport(String)
    /// Missing or invalid user JWT for a write / saved / moderation action.
    case unauthorized
    /// Empty title/body, bad image MIME/size, invalid poll, etc.
    case invalidRequest(String)
    /// Unexpected JSON shape or non-mapped failure.
    case invalidResponse
    /// Requested post / poll / comment was not found (or filtered by RLS).
    case notFound

    static let defaultOfflineMessage =
        "Community needs a connection. Check your network and try again."

    var errorDescription: String? {
        switch self {
        case let .transport(detail):
            detail.isEmpty ? Self.defaultOfflineMessage : detail
        case .unauthorized:
            "Sign in to use Community."
        case let .invalidRequest(detail):
            detail.isEmpty ? "That Community request wasn't valid." : detail
        case .invalidResponse:
            "Community sent back something we didn't expect. Please try again."
        case .notFound:
            "We couldn't find that post."
        }
    }
}
