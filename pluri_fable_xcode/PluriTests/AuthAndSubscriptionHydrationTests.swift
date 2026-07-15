import Testing
@testable import Pluri

@Suite("MockSubscriptionService entitlement hydration")
struct MockSubscriptionServiceTests {
    @Test("Refresh marks customer info resolved for M2-08 / M2-18")
    @MainActor
    func refreshResolvesEntitlement() async {
        let mock = MockSubscriptionService(isPluriProActive: true)
        #expect(mock.hasResolvedCustomerInfo == false)
        #expect(mock.isPluriProActive == true)

        await mock.refresh()

        #expect(mock.hasResolvedCustomerInfo == true)
        #expect(mock.isPluriProActive == true)
    }

    @Test("Inactive entitlement stays inactive after resolve")
    @MainActor
    func inactiveEntitlementAfterResolve() async {
        let mock = MockSubscriptionService(isPluriProActive: false)
        await mock.refresh()
        #expect(mock.hasResolvedCustomerInfo == true)
        #expect(mock.isPluriProActive == false)
    }
}

@Suite("MockSupabaseAuthService")
struct MockSupabaseAuthServiceTests {
    @Test("Restore marks session resolved")
    @MainActor
    func restoreResolvesSession() async {
        let mock = MockSupabaseAuthService()
        #expect(mock.hasResolvedSession == false)
        await mock.restoreSession()
        #expect(mock.hasResolvedSession == true)
        #expect(mock.isSignedIn == false)
    }

    @Test("Delete account requires signed-in user")
    @MainActor
    func deleteAccountRequiresSignIn() async {
        let mock = MockSupabaseAuthService(isSignedIn: false)
        await #expect(throws: PluriAuthError.notSignedIn) {
            try await mock.deleteAccount()
        }
    }

    @Test("Delete account clears signed-in state")
    @MainActor
    func deleteAccountClearsSignedIn() async throws {
        let mock = MockSupabaseAuthService(isSignedIn: true)
        try await mock.deleteAccount()
        #expect(mock.isSignedIn == false)
    }
}
