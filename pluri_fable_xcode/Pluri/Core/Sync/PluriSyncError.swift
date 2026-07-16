import Foundation

/// Typed errors for onboarding flush / remote restore (M2-14 / M2-15).
nonisolated enum PluriSyncError: Error, Equatable, Sendable {
    case notSignedIn
    case incompleteAnswers
    case flushFailed(String)
    case restoreFailed(String)
    case networkUnavailable

    var userFacingMessage: String {
        switch self {
        case .notSignedIn:
            "You’re not signed in. Please sign in and try again."
        case .incompleteAnswers:
            "We still need a few answers before we can save your plan."
        case .flushFailed(let detail):
            detail.isEmpty
                ? "We couldn’t save your plan just now. Please try again."
                : detail
        case .restoreFailed(let detail):
            detail.isEmpty
                ? "We couldn’t restore your plan just now. Please try again."
                : detail
        case .networkUnavailable:
            "Check your connection and try again."
        }
    }
}
