import Foundation

/// Billing period kind of the active `Pluri Pro` entitlement, mirrored from
/// RevenueCat's `PeriodType` so resolution logic stays pure and testable (M2-19).
nonisolated enum EntitlementPeriod: Equatable, Sendable {
    /// Regular paid period.
    case regular
    /// Free trial (ASC introductory offer, Free → 1 Month — SPEC §14 #7).
    case trial
    /// Paid introductory pricing period.
    case introductory
}

/// Resolved `Pluri Pro` entitlement state used by launch routing and UI (M2-18/19).
nonisolated enum EntitlementState: Equatable, Sendable {
    case inactive
    case active(period: EntitlementPeriod)

    var isEntitled: Bool {
        self != .inactive
    }

    /// Trial-ish state per SPEC §4: a free trial or introductory pricing period.
    var isInTrialPeriod: Bool {
        switch self {
        case .active(.trial), .active(.introductory): true
        case .active(.regular), .inactive: false
        }
    }
}

/// Pure entitlement + trial-state resolution, separated from RevenueCat types
/// so it can be unit-tested without constructing `CustomerInfo` (M2-19).
nonisolated enum EntitlementResolver {
    static func state(isActive: Bool, period: EntitlementPeriod?) -> EntitlementState {
        guard isActive else { return .inactive }
        return .active(period: period ?? .regular)
    }
}
