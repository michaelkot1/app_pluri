import Testing
@testable import Pluri

/// M2-19 — pure entitlement + trial-state resolution (SPEC §4), no RevenueCat
/// `CustomerInfo` construction required.
@Suite("EntitlementResolver")
struct EntitlementResolverTests {
    @Test("Inactive entitlement resolves to inactive regardless of period")
    func inactive() {
        #expect(EntitlementResolver.state(isActive: false, period: nil) == .inactive)
        #expect(EntitlementResolver.state(isActive: false, period: .trial) == .inactive)
        #expect(EntitlementResolver.state(isActive: false, period: .introductory) == .inactive)

        let state = EntitlementResolver.state(isActive: false, period: .regular)
        #expect(!state.isEntitled)
        #expect(!state.isInTrialPeriod)
    }

    @Test("Active regular period is entitled but not trial")
    func activeRegular() {
        let state = EntitlementResolver.state(isActive: true, period: .regular)
        #expect(state == .active(period: .regular))
        #expect(state.isEntitled)
        #expect(!state.isInTrialPeriod)
    }

    @Test("Active free trial is entitled and trial-like")
    func activeTrial() {
        let state = EntitlementResolver.state(isActive: true, period: .trial)
        #expect(state == .active(period: .trial))
        #expect(state.isEntitled)
        #expect(state.isInTrialPeriod)
    }

    @Test("Active introductory period is entitled and trial-like")
    func activeIntroductory() {
        let state = EntitlementResolver.state(isActive: true, period: .introductory)
        #expect(state == .active(period: .introductory))
        #expect(state.isEntitled)
        #expect(state.isInTrialPeriod)
    }

    @Test("Active with unknown period defaults to regular")
    func activeUnknownPeriod() {
        let state = EntitlementResolver.state(isActive: true, period: nil)
        #expect(state == .active(period: .regular))
        #expect(state.isEntitled)
        #expect(!state.isInTrialPeriod)
    }
}
