import Foundation
import Testing
@testable import Pluri

@Suite("AppLaunchGate skip criterion")
struct AppLaunchGateCriterionTests {
    @Test("Completed profile skips questionnaire")
    func completedProfileSkips() {
        let userID = UUID()
        let restored = RestoredUserState(profile: makeProfile(completed: true), plan: nil)
        #expect(
            AppLaunchGate.shouldSkipQuestionnaire(
                restored: restored,
                userID: userID,
                restoreFailed: false
            )
        )
    }

    @Test("Active plan skips even when onboardingCompleted is false")
    func activePlanSkips() {
        let userID = UUID()
        let plan = GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .flexible,
            sessionDurationMinutes: 45,
            startDate: .now,
            weeks: [
                PlanWeek(number: 1, sessions: [])
            ],
            seed: 1
        )
        let restored = RestoredUserState(profile: makeProfile(completed: false), plan: plan)
        #expect(
            AppLaunchGate.shouldSkipQuestionnaire(
                restored: restored,
                userID: userID,
                restoreFailed: false
            )
        )
    }

    @Test("Incomplete profile without plan does not skip")
    func incompleteDoesNotSkip() {
        let userID = UUID()
        let restored = RestoredUserState(profile: makeProfile(completed: false), plan: nil)
        #expect(
            !AppLaunchGate.shouldSkipQuestionnaire(
                restored: restored,
                userID: userID,
                restoreFailed: false
            )
        )
    }

    @Test("Nil profile does not skip when restore succeeded")
    func nilProfileDoesNotSkip() {
        let userID = UUID()
        #expect(
            !AppLaunchGate.shouldSkipQuestionnaire(
                restored: nil,
                userID: userID,
                restoreFailed: false
            )
        )
    }

    @Test("Offline restore failure uses local hint")
    func offlineHintSkips() {
        let userID = UUID()
        OnboardingCompletionHintStore.clear(userID: userID)
        defer { OnboardingCompletionHintStore.clear(userID: userID) }

        #expect(
            !AppLaunchGate.shouldSkipQuestionnaire(
                restored: nil,
                userID: userID,
                restoreFailed: true
            )
        )

        OnboardingCompletionHintStore.markCompleted(userID: userID)
        #expect(
            AppLaunchGate.shouldSkipQuestionnaire(
                restored: nil,
                userID: userID,
                restoreFailed: true
            )
        )
    }
}

@Suite("AppLaunchGate resolve matrix")
struct AppLaunchGateResolveTests {
    @Test("Fresh signed-out goes to onboarding")
    @MainActor
    func freshSignedOut() async {
        let auth = MockSupabaseAuthService(isSignedIn: false, hasResolvedSession: true)
        let subscriptions = MockSubscriptionService(hasResolvedCustomerInfo: true)
        let flush = MockOnboardingFlushService()
        let restore = MockRemotePlanRestoreService()
        let gate = AppLaunchGate()

        await gate.resolve(
            authService: auth,
            subscriptionService: subscriptions,
            flushService: flush,
            restoreService: restore
        )

        #expect(gate.route == .onboarding)
        #expect(flush.retryCount == 0)
        #expect(restore.restoreCount == 0)
        #expect(subscriptions.lastLoggedInAppUserID == nil)
    }

    @Test("Signed-in completed skips questionnaire")
    @MainActor
    func signedInCompleted() async {
        let auth = MockSupabaseAuthService(isSignedIn: true, hasResolvedSession: true)
        let userID = UUID(uuidString: auth.mockAppUserID)!
        OnboardingCompletionHintStore.clear(userID: userID)
        defer { OnboardingCompletionHintStore.clear(userID: userID) }

        let subscriptions = MockSubscriptionService(
            isPluriProActive: true,
            hasResolvedCustomerInfo: true
        )
        let flush = MockOnboardingFlushService()
        let restore = MockRemotePlanRestoreService()
        restore.result = RestoredUserState(profile: makeProfile(completed: true), plan: nil)
        let gate = AppLaunchGate()

        await gate.resolve(
            authService: auth,
            subscriptionService: subscriptions,
            flushService: flush,
            restoreService: restore
        )

        #expect(gate.route == .welcomeBack(restore.result))
        #expect(flush.retryCount == 1)
        #expect(restore.restoreCount == 1)
        #expect(subscriptions.lastLoggedInAppUserID == auth.mockAppUserID)
        #expect(OnboardingCompletionHintStore.isCompleted(userID: userID))
    }

    @Test("Signed-in incomplete stays on onboarding")
    @MainActor
    func signedInIncomplete() async {
        let auth = MockSupabaseAuthService(isSignedIn: true, hasResolvedSession: true)
        let userID = UUID(uuidString: auth.mockAppUserID)!
        OnboardingCompletionHintStore.clear(userID: userID)
        defer { OnboardingCompletionHintStore.clear(userID: userID) }

        let subscriptions = MockSubscriptionService(hasResolvedCustomerInfo: true)
        let flush = MockOnboardingFlushService()
        let restore = MockRemotePlanRestoreService()
        restore.result = RestoredUserState(profile: makeProfile(completed: false), plan: nil)
        let gate = AppLaunchGate()

        await gate.resolve(
            authService: auth,
            subscriptionService: subscriptions,
            flushService: flush,
            restoreService: restore
        )

        #expect(gate.route == .onboarding)
        #expect(flush.retryCount == 1)
        #expect(restore.restoreCount == 1)
    }

    @Test("Lapsed entitlement still skips when onboarding completed")
    @MainActor
    func lapsedEntitlementStillSkips() async {
        let auth = MockSupabaseAuthService(isSignedIn: true, hasResolvedSession: true)
        let userID = UUID(uuidString: auth.mockAppUserID)!
        OnboardingCompletionHintStore.clear(userID: userID)
        defer { OnboardingCompletionHintStore.clear(userID: userID) }

        UserDefaults.standard.removeObject(forKey: PluriSubscription.debugBypassPaywallKey)
        let subscriptions = MockSubscriptionService(
            isPluriProActive: false,
            hasResolvedCustomerInfo: true
        )
        #expect(subscriptions.isPluriProActive == false)

        let flush = MockOnboardingFlushService()
        let restore = MockRemotePlanRestoreService()
        restore.result = RestoredUserState(profile: makeProfile(completed: true), plan: nil)
        let gate = AppLaunchGate()

        await gate.resolve(
            authService: auth,
            subscriptionService: subscriptions,
            flushService: flush,
            restoreService: restore
        )

        #expect(gate.route == .welcomeBack(restore.result))
        #expect(subscriptions.isPluriProActive == false)
    }

    @Test("Checkpoint retry is invoked when signed in")
    @MainActor
    func checkpointRetryInvoked() async {
        let auth = MockSupabaseAuthService(isSignedIn: true, hasResolvedSession: true)
        let userID = UUID(uuidString: auth.mockAppUserID)!
        OnboardingCompletionHintStore.clear(userID: userID)
        defer { OnboardingCompletionHintStore.clear(userID: userID) }

        let subscriptions = MockSubscriptionService(hasResolvedCustomerInfo: true)
        let flush = MockOnboardingFlushService()
        flush.retryReturnsFlushed = true
        let restore = MockRemotePlanRestoreService()
        restore.result = nil
        let gate = AppLaunchGate()

        await gate.resolve(
            authService: auth,
            subscriptionService: subscriptions,
            flushService: flush,
            restoreService: restore
        )

        #expect(flush.retryCount == 1)
        // Hint is marked from checkpoint success; remote nil + restoreSucceeded → still onboarding (remote wins).
        #expect(OnboardingCompletionHintStore.isCompleted(userID: userID))
        #expect(gate.route == .onboarding)
    }

    @Test("Restore failure with local hint skips questionnaire")
    @MainActor
    func restoreFailureWithHint() async {
        let auth = MockSupabaseAuthService(isSignedIn: true, hasResolvedSession: true)
        let userID = UUID(uuidString: auth.mockAppUserID)!
        OnboardingCompletionHintStore.markCompleted(userID: userID)
        defer { OnboardingCompletionHintStore.clear(userID: userID) }

        let subscriptions = MockSubscriptionService(hasResolvedCustomerInfo: true)
        let flush = MockOnboardingFlushService()
        let restore = MockRemotePlanRestoreService()
        restore.nextError = .networkUnavailable
        let gate = AppLaunchGate()

        await gate.resolve(
            authService: auth,
            subscriptionService: subscriptions,
            flushService: flush,
            restoreService: restore
        )

        #expect(gate.route == .welcomeBack(nil))
        #expect(restore.restoreCount == 1)
    }

    @Test("Sign-out clears completion hint")
    @MainActor
    func signOutClearsHint() async throws {
        let auth = MockSupabaseAuthService(isSignedIn: true, hasResolvedSession: true)
        let userID = UUID(uuidString: auth.mockAppUserID)!
        OnboardingCompletionHintStore.markCompleted(userID: userID)
        #expect(OnboardingCompletionHintStore.isCompleted(userID: userID))

        try await auth.signOut()
        #expect(!OnboardingCompletionHintStore.isCompleted(userID: userID))
    }
}

private func makeProfile(completed: Bool) -> RestoredProfile {
    RestoredProfile(
        displayName: "Alex",
        goal: .buildMuscle,
        experience: .oneToSixMonths,
        regularity: .onAndOff,
        location: .commercialGym,
        injuries: [:],
        trainingDays: [.monday],
        scheduleType: .flexible,
        planLengthWeeks: 8,
        sessionDuration: .fortyFiveMinutes,
        age: 28,
        gender: .male,
        heightCM: 180,
        weightKG: 80,
        allergies: [],
        equipment: ["Barbell"],
        startDate: .now,
        maintenanceCalories: 2200,
        units: "metric",
        onboardingCompleted: completed
    )
}
