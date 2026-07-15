import Foundation
import RevenueCat

/// In-memory subscription stand-in for previews and unit tests (M2-07 / M2-08 / M2-19).
///
/// Lapse → locked paywall later (M2-18); mock never deletes local content on entitlement change.
@MainActor
@Observable
final class MockSubscriptionService: SubscriptionServicing {
    private(set) var customerInfo: CustomerInfo?
    private(set) var hasResolvedCustomerInfo = false
    private(set) var offerings: Offerings?
    private(set) var isLoading = false
    private(set) var lastError: PluriSubscriptionError?

    private var entitled: Bool

    var isPluriProActive: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: PluriSubscription.debugBypassPaywallKey) {
            return true
        }
        #endif
        return entitled
    }

    init(isPluriProActive: Bool = false, hasResolvedCustomerInfo: Bool = false) {
        self.entitled = isPluriProActive
        self.hasResolvedCustomerInfo = hasResolvedCustomerInfo
    }

    func refresh() async {
        isLoading = true
        defer {
            isLoading = false
            hasResolvedCustomerInfo = true
        }
        lastError = nil
    }

    func restore() async throws {
        isLoading = true
        defer {
            isLoading = false
            hasResolvedCustomerInfo = true
        }
        entitled = true
        lastError = nil
    }

    func purchase(_ package: Package) async throws {
        _ = package
        entitled = true
        lastError = nil
    }

    func purchaseMonthly() async throws {
        entitled = true
        lastError = nil
    }

    func purchaseYearly() async throws {
        entitled = true
        lastError = nil
    }

    #if DEBUG
    func enableDebugPaywallBypass() {
        UserDefaults.standard.set(true, forKey: PluriSubscription.debugBypassPaywallKey)
    }
    #endif
}
