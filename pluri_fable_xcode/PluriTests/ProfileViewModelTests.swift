import Foundation
import Testing
@testable import Pluri

// MARK: - Plan summary

@Suite("ProfilePlanSummary")
@MainActor
struct ProfilePlanSummaryTests {
    @Test("Active plan produces goal, dates, and schedule")
    func activePlanSummary() throws {
        let plan = makePlan(sessionsPerWeek: 3, weeks: 6)
        let summary = ProfilePlanSummary.make(from: plan)

        let unwrapped = try #require(summary)
        #expect(unwrapped.goalTitle == "Build muscle")
        #expect(unwrapped.dateRangeText.contains(plan.startDate.formatted(date: .abbreviated, time: .omitted)))
        #expect(unwrapped.dateRangeText.contains(plan.endDate.formatted(date: .abbreviated, time: .omitted)))
        #expect(unwrapped.scheduleText == "Scheduled · 3 workouts / week · 45 min")
    }

    @Test("Single-session week uses singular wording")
    func singularSchedule() {
        let summary = ProfilePlanSummary.make(from: makePlan(sessionsPerWeek: 1, weeks: 4))
        #expect(summary?.scheduleText == "Scheduled · 1 workout / week · 45 min")
    }

    @Test("No active plan produces nil")
    func noPlanSummary() {
        #expect(ProfilePlanSummary.make(from: nil) == nil)
    }
}

// MARK: - Theme persistence

@Suite("ThemeStore")
@MainActor
struct ThemeStoreTests {
    @Test("Defaults to system before any selection")
    func defaultsToSystem() {
        let defaults = makeThrowawayDefaults()
        defer { cleanUp(defaults) }

        #expect(ThemeStore(defaults: defaults).selection == .system)
    }

    @Test("Selection persists across store instances")
    func selectionPersists() {
        let defaults = makeThrowawayDefaults()
        defer { cleanUp(defaults) }

        let store = ThemeStore(defaults: defaults)
        store.selection = .dark
        #expect(ThemeStore(defaults: defaults).selection == .dark)

        store.selection = .light
        #expect(ThemeStore(defaults: defaults).selection == .light)
    }

    private func makeThrowawayDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ThemeStoreTests-\(UUID().uuidString)")!
    }

    private func cleanUp(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: ThemeStore.defaultsKey)
    }
}

// MARK: - Account actions

/// Serialized: these tests share the single `FlushCheckpointStore` slot in
/// `UserDefaults.standard`.
@Suite("ProfileViewModel account actions", .serialized)
@MainActor
struct ProfileViewModelTests {
    @Test("Sign out ends auth + RevenueCat sessions, clears local user state, and reroutes")
    func signOutHappyPath() async {
        let auth = MockSupabaseAuthService(isSignedIn: true, hasResolvedSession: true)
        let userID = UUID(uuidString: auth.mockAppUserID)!
        OnboardingCompletionHintStore.markCompleted(userID: userID)
        FlushCheckpointStore.save(makeCheckpoint(userID: userID))
        defer {
            OnboardingCompletionHintStore.clear(userID: userID)
            FlushCheckpointStore.clear()
        }

        let subscriptions = MockSubscriptionService()
        let reroutes = RerouteRecorder()
        let viewModel = ProfileViewModel(
            authService: auth,
            subscriptionService: subscriptions,
            onAccountEnded: { reroutes.count += 1 }
        )

        await viewModel.signOut()

        #expect(auth.signOutCallCount == 1)
        #expect(!auth.isSignedIn)
        #expect(subscriptions.logOutCallCount == 1)
        #expect(!OnboardingCompletionHintStore.isCompleted(userID: userID))
        #expect(FlushCheckpointStore.load() == nil)
        #expect(reroutes.count == 1)
        #expect(viewModel.lastError == nil)
        #expect(viewModel.activeAction == nil)
    }

    @Test("Sign out does not clear another user's pending checkpoint")
    func signOutPreservesOtherUsersCheckpoint() async {
        let auth = MockSupabaseAuthService(isSignedIn: true, hasResolvedSession: true)
        let otherUserID = UUID()
        let otherCheckpoint = makeCheckpoint(userID: otherUserID)
        FlushCheckpointStore.save(otherCheckpoint)
        defer { FlushCheckpointStore.clear() }

        let viewModel = ProfileViewModel(
            authService: auth,
            subscriptionService: MockSubscriptionService(),
            onAccountEnded: {}
        )

        await viewModel.signOut()

        #expect(FlushCheckpointStore.load() == otherCheckpoint)
    }

    @Test("Cancelling the delete confirmation performs no account operations")
    func deleteCancellationDoesNothing() async {
        let auth = MockSupabaseAuthService(isSignedIn: true, hasResolvedSession: true)
        let userID = UUID(uuidString: auth.mockAppUserID)!
        FlushCheckpointStore.save(makeCheckpoint(userID: userID))
        defer { FlushCheckpointStore.clear() }

        let subscriptions = MockSubscriptionService()
        let reroutes = RerouteRecorder()
        let viewModel = ProfileViewModel(
            authService: auth,
            subscriptionService: subscriptions,
            onAccountEnded: { reroutes.count += 1 }
        )

        viewModel.requestDeleteAccount()
        #expect(viewModel.isDeleteConfirmationPresented)

        viewModel.cancelDeleteAccount()

        #expect(!viewModel.isDeleteConfirmationPresented)
        #expect(auth.deleteAccountCallCount == 0)
        #expect(subscriptions.logOutCallCount == 0)
        #expect(auth.isSignedIn)
        #expect(FlushCheckpointStore.load() != nil)
        #expect(reroutes.count == 0)
    }

    @Test("Confirmed deletion wipes local user state and reroutes")
    func deleteSuccessWipesAndReroutes() async {
        let auth = MockSupabaseAuthService(isSignedIn: true, hasResolvedSession: true)
        let userID = UUID(uuidString: auth.mockAppUserID)!
        OnboardingCompletionHintStore.markCompleted(userID: userID)
        FlushCheckpointStore.save(makeCheckpoint(userID: userID))
        defer {
            OnboardingCompletionHintStore.clear(userID: userID)
            FlushCheckpointStore.clear()
        }

        let subscriptions = MockSubscriptionService()
        let reroutes = RerouteRecorder()
        let viewModel = ProfileViewModel(
            authService: auth,
            subscriptionService: subscriptions,
            onAccountEnded: { reroutes.count += 1 }
        )

        viewModel.requestDeleteAccount()
        await viewModel.confirmDeleteAccount()

        #expect(auth.deleteAccountCallCount == 1)
        #expect(!auth.isSignedIn)
        #expect(subscriptions.logOutCallCount == 1)
        #expect(!OnboardingCompletionHintStore.isCompleted(userID: userID))
        #expect(FlushCheckpointStore.load() == nil)
        #expect(reroutes.count == 1)
        #expect(viewModel.lastError == nil)
    }

    @Test("Failed deletion keeps the user signed in with local state intact")
    func deleteFailurePreservesState() async {
        let auth = MockSupabaseAuthService(isSignedIn: true, hasResolvedSession: true)
        auth.shouldFailAccountDeletion = true
        let userID = UUID(uuidString: auth.mockAppUserID)!
        OnboardingCompletionHintStore.markCompleted(userID: userID)
        FlushCheckpointStore.save(makeCheckpoint(userID: userID))
        defer {
            OnboardingCompletionHintStore.clear(userID: userID)
            FlushCheckpointStore.clear()
        }

        let subscriptions = MockSubscriptionService()
        let reroutes = RerouteRecorder()
        let viewModel = ProfileViewModel(
            authService: auth,
            subscriptionService: subscriptions,
            onAccountEnded: { reroutes.count += 1 }
        )

        await viewModel.confirmDeleteAccount()

        #expect(viewModel.lastError == .accountDeletionFailed("Mock deletion failure"))
        #expect(auth.isSignedIn)
        #expect(subscriptions.logOutCallCount == 0)
        #expect(OnboardingCompletionHintStore.isCompleted(userID: userID))
        #expect(FlushCheckpointStore.load() != nil)
        #expect(reroutes.count == 0)
        #expect(viewModel.activeAction == nil)
    }

    @Test("Overlapping sign-out taps run the operation once")
    func duplicateSignOutTapsRunOnce() async {
        let auth = MockSupabaseAuthService(isSignedIn: true, hasResolvedSession: true)
        auth.accountOperationDelay = .milliseconds(50)
        let subscriptions = MockSubscriptionService()
        let reroutes = RerouteRecorder()
        let viewModel = ProfileViewModel(
            authService: auth,
            subscriptionService: subscriptions,
            onAccountEnded: { reroutes.count += 1 }
        )

        async let first: Void = viewModel.signOut()
        async let second: Void = viewModel.signOut()
        _ = await (first, second)

        #expect(auth.signOutCallCount == 1)
        #expect(subscriptions.logOutCallCount == 1)
        #expect(reroutes.count == 1)
    }

    @Test("Overlapping delete confirmations run the operation once")
    func duplicateDeleteTapsRunOnce() async {
        let auth = MockSupabaseAuthService(isSignedIn: true, hasResolvedSession: true)
        auth.accountOperationDelay = .milliseconds(50)
        let viewModel = ProfileViewModel(
            authService: auth,
            subscriptionService: MockSubscriptionService(),
            onAccountEnded: {}
        )

        async let first: Void = viewModel.confirmDeleteAccount()
        async let second: Void = viewModel.confirmDeleteAccount()
        _ = await (first, second)

        #expect(auth.deleteAccountCallCount == 1)
    }
}

// MARK: - Checkpoint scoping

@Suite("FlushCheckpointStore user scoping", .serialized)
struct FlushCheckpointStoreScopingTests {
    @Test("clear(userID:) removes only the owner's checkpoint")
    func clearIsUserScoped() {
        let owner = UUID()
        let stranger = UUID()
        let checkpoint = makeCheckpoint(userID: owner)
        FlushCheckpointStore.save(checkpoint)
        defer { FlushCheckpointStore.clear() }

        FlushCheckpointStore.clear(userID: stranger)
        #expect(FlushCheckpointStore.load() == checkpoint)

        FlushCheckpointStore.clear(userID: owner)
        #expect(FlushCheckpointStore.load() == nil)
    }
}

// MARK: - Fixtures

@MainActor
private final class RerouteRecorder {
    var count = 0
}

private func makePlan(sessionsPerWeek: Int, weeks: Int) -> GeneratedPlan {
    let sessions = (1...sessionsPerWeek).map { index in
        PlannedSession(
            title: "Workout \(index)",
            indexInWeek: index,
            weekday: nil,
            date: nil,
            exercises: []
        )
    }
    return GeneratedPlan(
        goal: .buildMuscle,
        scheduleType: .scheduled,
        sessionDurationMinutes: 45,
        startDate: Date(timeIntervalSince1970: 1_784_000_000),
        weeks: (1...weeks).map { PlanWeek(number: $0, sessions: sessions) },
        seed: 7
    )
}

private func makeCheckpoint(userID: UUID) -> FlushCheckpointStore.Checkpoint {
    FlushCheckpointStore.Checkpoint(
        userID: userID,
        profile: ProfileUpsertRow(
            id: userID,
            displayName: "Alex",
            goal: "build_muscle",
            trainingExperience: "1_6_months",
            trainingRegularity: "on_and_off",
            workoutLocation: "commercial_gym",
            injuries: [],
            daysPerWeek: 3,
            workoutDays: ["mon"],
            scheduleType: "scheduled",
            programWeeks: 6,
            sessionMinutes: 45,
            age: 28,
            gender: "male",
            heightCm: 180,
            weightKg: 80,
            startDate: "2026-07-20",
            onboardingCompleted: true,
            units: "metric",
            maintenanceCalories: 2200,
            allergies: [],
            equipment: ["Barbell"]
        ),
        planTree: FlushCheckpointStore.PlanTreeCheckpoint(
            plan: PlanInsertRow(
                id: UUID(),
                userId: userID,
                goal: "build_muscle",
                name: nil,
                startDate: "2026-07-20",
                endDate: "2026-08-30",
                weeks: 6,
                scheduleType: "scheduled",
                status: "active"
            ),
            workouts: [],
            exercises: []
        ),
        savedAt: .now
    )
}
