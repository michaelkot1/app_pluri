import Foundation

/// RevenueCat identifiers for Pluri Pro (SPEC §4 / §14).
enum PluriSubscription {
    /// Entitlement configured in the RevenueCat dashboard.
    static let entitlementID = "Pluri Pro"

    /// App Store / RevenueCat product identifiers for the default offering packages.
    static let monthlyProductID = "monthly"
    static let yearlyProductID = "yearly"

    #if DEBUG
    /// UserDefaults key that unlocks Pluri Pro without a purchase (DEBUG only).
    static let debugBypassPaywallKey = "debug.bypassPaywall"
    #endif
}
