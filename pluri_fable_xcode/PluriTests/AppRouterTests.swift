import Foundation
import Testing
@testable import Pluri

@Suite("AppRouter skip criterion")
struct AppRouterCriterionTests {
    @Test("Completed profile skips questionnaire")
    func completedProfileSkips() {
        let userID = UUID()
        let restored = RestoredUserState(profile: makeProfile(completed: true), plan: nil)
        #expect(
            AppRouter.shouldSkipQuestionnaire(
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
            AppRouter.shouldSkipQuestionnaire(
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
            !AppRouter.shouldSkipQuestionnaire(
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
            !AppRouter.shouldSkipQuestionnaire(
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
            !AppRouter.shouldSkipQuestionnaire(
                restored: nil,
                userID: userID,
                restoreFailed: true
            )
        )

        OnboardingCompletionHintStore.markCompleted(userID: userID)
        #expect(
            AppRouter.shouldSkipQuestionnaire(
                restored: nil,
                userID: userID,
                restoreFailed: true
            )
        )
    }
}

/// M2-19 launch-routing state machine: fresh / signed-out / incomplete signed-in /
/// entitled signed-in / lapsed signed-in (SPEC §4, PLAN §1.2).
@Suite("AppRouter launch routing matrix")
struct AppRouterResolveTests {
    @MainActor
    private func resolve(
        _ router: AppRouter,
        auth: MockSupabaseAuthService,
        subscriptions: MockSubscriptionService,
        flush: MockOnboardingFlushService,
        restore: MockRemotePlanRestoreService
    ) async {
        router.finishSplash()
        await router.resolve(
            authService: auth,
            subscriptionService: subscriptions,
            flushService: flush,
            restoreService: restore
        )
    }

    @Test("Fresh install / signed-out goes to onboarding")
    @MainActor
    func freshSignedOut() async {
        let auth = MockSupabaseAuthService(isSignedIn: false, hasResolvedSession: true)
        let subscriptions = MockSubscriptionService(hasResolvedCustomerInfo: true)
        let flush = MockOnboardingFlushService()
        let restore = MockRemotePlanRestoreService()
        let router = AppRouter()

        await resolve(router, auth: auth, subscriptions: subscriptions, flush: flush, restore: restore)

        #expect(router.phase == .onboarding)
        #expect(flush.retryCount == 0)
        #expect(restore.restoreCount == 0)
        #expect(subscriptions.lastLoggedInAppUserID == nil)
    }

    @Test("Splash is held until both hydration and the brand moment finish")
    @MainActor
    func splashGatesFirstTransition() async {
        let auth = MockSupabaseAuthService(isSignedIn: false, hasResolvedSession: true)
        let subscriptions = MockSubscriptionService(hasResolvedCustomerInfo: true)
        let router = AppRouter()

        await router.resolve(
            authService: auth,
            subscriptionService: subscriptions,
            flushService: MockOnboardingFlushService(),
            restoreService: MockRemotePlanRestoreService()
        )
        // Resolution finished, but the splash hasn't — no onboarding flash.
        #expect(router.phase == .splash)

        router.finishSplash()
        #expect(router.phase == .onboarding)
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
        let router = AppRouter()

        await resolve(router, auth: auth, subscriptions: subscriptions, flush: flush, restore: restore)

        #expect(router.phase == .onboarding)
        #expect(flush.retryCount == 1)
        #expect(restore.restoreCount == 1)
    }

    @Test("Signed-in completed entitled lands on Main")
    @MainActor
    func signedInCompletedEntitled() async {
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
        let router = AppRouter()

        await resolve(router, auth: auth, subscriptions: subscriptions, flush: flush, restore: restore)

        #expect(router.phase == .main)
        #expect(router.restoredState == restore.result)
        #expect(router.paywallPayload == nil)
        #expect(flush.retryCount == 1)
        #expect(restore.restoreCount == 1)
        #expect(subscriptions.lastLoggedInAppUserID == auth.mockAppUserID)
        #expect(OnboardingCompletionHintStore.isCompleted(userID: userID))
    }

    @Test("Signed-in completed lapsed lands on locked paywall, content preserved")
    @MainActor
    func signedInCompletedLapsed() async {
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
        let router = AppRouter()

        await resolve(router, auth: auth, subscriptions: subscriptions, flush: flush, restore: restore)

        #expect(router.phase == .paywall)
        // No onboarding payload ⇒ the locked lapsed context, not the funnel paywall.
        #expect(router.paywallPayload == nil)
        // Restored content is preserved behind the locked paywall (SPEC §4).
        #expect(router.restoredState == restore.result)

        router.unlockFromLockedPaywall()
        #expect(router.phase == .main)
        #expect(router.restoredState == restore.result)
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
        let router = AppRouter()

        await resolve(router, auth: auth, subscriptions: subscriptions, flush: flush, restore: restore)

        #expect(flush.retryCount == 1)
        // Hint is marked from checkpoint success; remote nil + restore succeeded → onboarding (remote wins).
        #expect(OnboardingCompletionHintStore.isCompleted(userID: userID))
        #expect(router.phase == .onboarding)
    }

    @Test("Restore failure with local hint skips questionnaire")
    @MainActor
    func restoreFailureWithHint() async {
        let auth = MockSupabaseAuthService(isSignedIn: true, hasResolvedSession: true)
        let userID = UUID(uuidString: auth.mockAppUserID)!
        OnboardingCompletionHintStore.markCompleted(userID: userID)
        defer { OnboardingCompletionHintStore.clear(userID: userID) }

        let subscriptions = MockSubscriptionService(
            isPluriProActive: true,
            hasResolvedCustomerInfo: true
        )
        let flush = MockOnboardingFlushService()
        let restore = MockRemotePlanRestoreService()
        restore.nextError = .networkUnavailable
        let router = AppRouter()

        await resolve(router, auth: auth, subscriptions: subscriptions, flush: flush, restore: restore)

        #expect(router.phase == .main)
        #expect(router.restoredState == nil)
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

@Suite("AppRouter funnel transitions")
struct AppRouterFunnelTests {
    @MainActor
    private func makeAnswersAndPlan() throws -> (OnboardingAnswers, GeneratedPlan) {
        let answers = OnboardingAnswers()
        answers.name = "Alex"
        answers.goal = .buildMuscle
        answers.experience = .oneToSixMonths
        answers.regularity = .onAndOff
        answers.location = .commercialGym
        answers.equipment = Set(EquipmentCatalog.all)
        answers.trainingDays = [.monday, .wednesday, .friday]
        answers.scheduleType = .scheduled
        answers.planLengthWeeks = 6
        answers.sessionDuration = .oneHour
        answers.age = 28
        answers.gender = .male
        answers.heightCM = 178
        answers.weightKG = 75
        let input = PlanInput(answers: answers)
        let plan = try PlanEngine.generate(
            input: input,
            catalog: .workoutXPreviewFixtures,
            seed: input.deterministicSeed
        )
        return (answers, plan)
    }

    @Test("Generated answers and plan reach the paywall phase")
    @MainActor
    func planReadyEntersPaywallPhase() throws {
        let (answers, plan) = try makeAnswersAndPlan()
        let router = AppRouter()

        router.showPaywall(answers: answers, plan: plan)

        #expect(router.phase == .paywall)
        #expect(router.paywallPayload?.plan.id == plan.id)
        #expect(router.paywallPayload?.answers.name == "Alex")
    }

    @Test("Successful flush advances to Main with the local plan")
    @MainActor
    func flushSuccessAdvancesToMain() throws {
        let (answers, plan) = try makeAnswersAndPlan()
        let router = AppRouter()
        router.showPaywall(answers: answers, plan: plan)

        router.completeOnboardingFlush()

        #expect(router.phase == .main)
        #expect(router.paywallPayload == nil)
        #expect(router.restoredState?.plan?.id == plan.id)
        #expect(router.restoredState?.profile.displayName == "Alex")
    }

    @Test("Sign-out / delete reroutes to onboarding and clears state")
    @MainActor
    func resetToOnboardingClearsState() throws {
        let (answers, plan) = try makeAnswersAndPlan()
        let router = AppRouter()
        router.showPaywall(answers: answers, plan: plan)
        router.completeOnboardingFlush()

        router.resetToOnboarding()

        #expect(router.phase == .onboarding)
        #expect(router.paywallPayload == nil)
        #expect(router.restoredState == nil)
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
