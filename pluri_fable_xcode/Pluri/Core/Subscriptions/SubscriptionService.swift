import Foundation
import RevenueCat
import os.log

/// Live RevenueCat-backed subscription service (M2-07 / M2-08). Observes `CustomerInfo`
/// so launch routing (M2-18) can read entitlement state without talking to StoreKit directly.
///
/// Lapse → locked paywall later (M2-18); local content is preserved, never wiped on entitlement loss.
@MainActor
@Observable
final class SubscriptionService: SubscriptionServicing {
    private(set) var customerInfo: CustomerInfo?
    private(set) var hasResolvedCustomerInfo = false
    private(set) var offerings: Offerings?
    private(set) var isLoading = false
    private(set) var lastError: PluriSubscriptionError?

    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "SubscriptionService")

    var isPluriProActive: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: PluriSubscription.debugBypassPaywallKey) {
            return true
        }
        #endif
        return customerInfo?
            .entitlements[PluriSubscription.entitlementID]?
            .isActive == true
    }

    /// Whether the active entitlement looks trial-like (`periodType` / intro).
    var isInTrialPeriod: Bool {
        guard let entitlement = customerInfo?.entitlements[PluriSubscription.entitlementID],
              entitlement.isActive else {
            return false
        }
        return entitlement.periodType == .trial || entitlement.periodType == .intro
    }

    init(configurePurchases: Bool = true) {
        if configurePurchases {
            Self.configureSharedPurchases()
            startListeningToCustomerInfo()
            Task { await refresh() }
        }
    }

    func refresh() async {
        isLoading = true
        lastError = nil
        defer {
            isLoading = false
            markCustomerInfoResolved()
        }

        do {
            async let info = Purchases.shared.customerInfo()
            async let nextOfferings = Purchases.shared.offerings()
            customerInfo = try await info
            offerings = try await nextOfferings
            logger.info("Refreshed RevenueCat customer info and offerings")
        } catch {
            lastError = .offeringsUnavailable
            logger.error("RevenueCat refresh failed: \(error.localizedDescription)")
        }
    }

    func restore() async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            customerInfo = try await Purchases.shared.restorePurchases()
            logger.info("Restored purchases via RevenueCat")
        } catch {
            let wrapped = PluriSubscriptionError.restoreFailed(error.localizedDescription)
            lastError = wrapped
            logger.error("Restore failed: \(error.localizedDescription)")
            throw wrapped
        }
    }

    func purchase(_ package: Package) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            customerInfo = result.customerInfo
            if result.userCancelled {
                let cancelled = PluriSubscriptionError.purchaseCancelled
                lastError = cancelled
                throw cancelled
            }
            logger.info("Purchase completed for package \(package.identifier)")
        } catch let error as PluriSubscriptionError {
            throw error
        } catch let error as ErrorCode {
            let wrapped = Self.mapPurchaseError(error)
            lastError = wrapped
            throw wrapped
        } catch {
            let wrapped = PluriSubscriptionError.purchaseFailed(error.localizedDescription)
            lastError = wrapped
            throw wrapped
        }
    }

    func purchaseMonthly() async throws {
        guard let package = package(matchingProductID: PluriSubscription.monthlyProductID) else {
            let missing = PluriSubscriptionError.packageNotFound(PluriSubscription.monthlyProductID)
            lastError = missing
            throw missing
        }
        try await purchase(package)
    }

    func purchaseYearly() async throws {
        guard let package = package(matchingProductID: PluriSubscription.yearlyProductID) else {
            let missing = PluriSubscriptionError.packageNotFound(PluriSubscription.yearlyProductID)
            lastError = missing
            throw missing
        }
        try await purchase(package)
    }

    #if DEBUG
    func enableDebugPaywallBypass() {
        UserDefaults.standard.set(true, forKey: PluriSubscription.debugBypassPaywallKey)
        logger.debug("DEBUG paywall bypass enabled")
    }
    #endif

    /// Lets RevenueCatUI callbacks push the latest `CustomerInfo` into observable state.
    func applyCustomerInfo(_ info: CustomerInfo) {
        customerInfo = info
        markCustomerInfoResolved()
    }

    // MARK: - Private

    private static func configureSharedPurchases() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: Secrets.revenueCatAPIKey)
    }

    private func startListeningToCustomerInfo() {
        Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                guard let self else { return }
                self.customerInfo = info
                self.markCustomerInfoResolved()
            }
        }
    }

    private func markCustomerInfoResolved() {
        if !hasResolvedCustomerInfo {
            hasResolvedCustomerInfo = true
        }
    }

    private func package(matchingProductID productID: String) -> Package? {
        guard let current = offerings?.current else { return nil }
        if let byIdentifier = current.package(identifier: productID) {
            return byIdentifier
        }
        return current.availablePackages.first {
            $0.storeProduct.productIdentifier == productID
        }
    }

    private static func mapPurchaseError(_ error: ErrorCode) -> PluriSubscriptionError {
        switch error {
        case .purchaseCancelledError:
            .purchaseCancelled
        case .paymentPendingError:
            .purchasePending
        default:
            .purchaseFailed(error.localizedDescription)
        }
    }
}
