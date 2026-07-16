import Foundation
import RevenueCat

/// Errors surfaced gently from subscription / paywall flows (SPEC §4).
enum PluriSubscriptionError: Error, Equatable, Sendable {
    case configurationMissing
    case offeringsUnavailable
    case packageNotFound(String)
    case purchaseCancelled
    case purchasePending
    case purchaseFailed(String)
    case restoreFailed(String)

    var userFacingMessage: String {
        switch self {
        case .configurationMissing:
            "Subscriptions aren’t set up yet. Please try again later."
        case .offeringsUnavailable:
            "We couldn’t load subscription options. Check your connection and try again."
        case .packageNotFound:
            "That plan isn’t available right now. Please try again later."
        case .purchaseCancelled:
            "Purchase cancelled."
        case .purchasePending:
            "Your purchase is pending approval. We’ll unlock Pluri Pro when it goes through."
        case .purchaseFailed(let detail):
            detail.isEmpty ? "Something went wrong with the purchase. Please try again." : detail
        case .restoreFailed(let detail):
            detail.isEmpty ? "We couldn’t restore purchases. Please try again." : detail
        }
    }
}

/// Abstraction over RevenueCat for live app use, previews, and tests (M2-07).
@MainActor
protocol SubscriptionServicing: AnyObject {
    var isPluriProActive: Bool { get }
    /// `true` after the first customer-info refresh/stream event so M2-18 can avoid a paywall flash.
    var hasResolvedCustomerInfo: Bool { get }
    var customerInfo: CustomerInfo? { get }
    var offerings: Offerings? { get }
    var isLoading: Bool { get }
    var lastError: PluriSubscriptionError? { get }

    func refresh() async
    func restore() async throws
    func purchase(_ package: Package) async throws
    func purchaseMonthly() async throws
    func purchaseYearly() async throws
    /// Aliases RevenueCat to the Supabase user id after auth (M2-11).
    func logIn(appUserID: String) async throws

    #if DEBUG
    func enableDebugPaywallBypass()
    #endif
}
