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

    /// Pure entitlement + trial resolution over the RevenueCat entitlement (M2-19).
    var entitlementState: EntitlementState {
        let entitlement = customerInfo?.entitlements[PluriSubscription.entitlementID]
        return EntitlementResolver.state(
            isActive: entitlement?.isActive == true,
            period: entitlement.map { Self.entitlementPeriod(from: $0.periodType) }
        )
    }

    /// Whether the active entitlement looks trial-like (`periodType` / intro).
    var isInTrialPeriod: Bool {
        entitlementState.isInTrialPeriod
    }

    /// `false` when RevenueCat is intentionally not configured for this build
    /// (no key, or a Test Store key outside DEBUG). Callers must not trap the user
    /// behind a paywall that can never complete a purchase.
    var areSubscriptionsAvailable: Bool { Purchases.isConfigured }

    init(configurePurchases: Bool = true) {
        if configurePurchases {
            if Self.configureSharedPurchases() {
                startListeningToCustomerInfo()
                Task { await refresh() }
            } else {
                // Don't leave launch routing waiting on customer info that will never arrive.
                lastError = .configurationMissing
                markCustomerInfoResolved()
            }
        }
    }

    func refresh() async {
        guard Purchases.isConfigured else {
            lastError = .configurationMissing
            markCustomerInfoResolved()
            return
        }

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
        try ensurePurchasesConfigured()

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

    func logIn(appUserID: String) async throws {
        try ensurePurchasesConfigured()

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let (info, _) = try await Purchases.shared.logIn(appUserID)
            customerInfo = info
            markCustomerInfoResolved()
            logger.info("RevenueCat logged in with app user id")
        } catch {
            let wrapped = PluriSubscriptionError.restoreFailed(error.localizedDescription)
            lastError = wrapped
            logger.error("RevenueCat logIn failed: \(error.localizedDescription)")
            throw wrapped
        }
    }

    func logOut() async throws {
        try ensurePurchasesConfigured()

        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            customerInfo = try await Purchases.shared.logOut()
            logger.info("RevenueCat logged out to anonymous user")
        } catch {
            let wrapped = PluriSubscriptionError.logOutFailed(error.localizedDescription)
            lastError = wrapped
            logger.error("RevenueCat logOut failed: \(error.localizedDescription)")
            throw wrapped
        }
    }

    func purchase(_ package: Package) async throws {
        try ensurePurchasesConfigured()

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

    private static func entitlementPeriod(from periodType: PeriodType) -> EntitlementPeriod {
        switch periodType {
        case .trial: .trial
        case .intro: .introductory
        default: .regular
        }
    }

    /// Configures RevenueCat once. Returns `false` when subscriptions are
    /// intentionally disabled for this build (see `RevenueCatConfiguration`).
    @discardableResult
    private static func configureSharedPurchases() -> Bool {
        // SwiftUI may re-evaluate `State(initialValue: SubscriptionService())` on
        // view re-init; only attempt configure once per process.
        if Purchases.isConfigured {
            return true
        }
        if didAttemptConfigure {
            return false
        }
        didAttemptConfigure = true

        #if DEBUG
        let isDebugBuild = true
        #else
        let isDebugBuild = false
        #endif

        switch RevenueCatConfiguration.resolve(apiKey: Secrets.revenueCatAPIKey, isDebugBuild: isDebugBuild) {
        case .enabled(let apiKey):
            #if DEBUG
            Purchases.logLevel = .debug
            #endif
            Purchases.configure(withAPIKey: apiKey)
            return true

        case .disabled(let reason):
            let configuration = RevenueCatConfiguration.disabled(reason)
            Logger(subsystem: "com.codewithmikey.pluri", category: "SubscriptionService")
                .warning("\(configuration.disabledLogMessage ?? "", privacy: .public)")
            return false
        }
    }

    private static var didAttemptConfigure = false

    private func ensurePurchasesConfigured() throws {
        guard Purchases.isConfigured else {
            let missing = PluriSubscriptionError.configurationMissing
            lastError = missing
            throw missing
        }
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
