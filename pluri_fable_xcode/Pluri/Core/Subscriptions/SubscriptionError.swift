import Foundation

/// Typed subscription errors surfaced gently to the UI (no raw StoreKit).
enum SubscriptionError: LocalizedError, Equatable {
    case notConfigured
    case noOfferings
    case packageUnavailable(String)
    case purchaseCancelled
    case purchasePending
    case purchaseFailed(String)
    case restoreFailed(String)
    case refreshFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Subscriptions aren’t set up yet. Please try again later."
        case .noOfferings:
            return "We couldn’t load subscription options. Check your connection and try again."
        case .packageUnavailable(let id):
            return "The \(id) plan isn’t available right now."
        case .purchaseCancelled:
            return "Purchase cancelled."
        case .purchasePending:
            return "Your purchase is pending approval."
        case .purchaseFailed(let message):
            return message
        case .restoreFailed(let message):
            return message
        case .refreshFailed(let message):
            return message
        }
    }
}
