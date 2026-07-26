import SwiftUI

/// Resolves a pushed `HomeRoute` to its destination view (M3-06). Profile is
/// the real M2-16 screen fed from the live `PlanStore` (falling back to the
/// launch-restored state), Calendar is the real M3-13 page, Notifications is
/// the real M3-15 page, Workout Detail (M4-05) and Workout Screen pre-start
/// (M4-07/08) are live; Outdoor Run stays an honest stub.
struct HomeRouteDestinationView: View {
    var route: HomeRoute
    /// Launch-restored state, kept as the Profile fallback before the store
    /// is hydrated.
    var restored: RestoredUserState?
    /// Root reroute after sign-out / account deletion (M2-17).
    var onAccountEnded: @MainActor @Sendable () -> Void

    @Environment(SupabaseAuthService.self) private var authService
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(PlanStore.self) private var planStore

    var body: some View {
        switch route {
        case .profile:
            ProfileView(
                restored: profileState,
                viewModel: ProfileViewModel(
                    authService: authService,
                    subscriptionService: subscriptionService,
                    onAccountEnded: { onAccountEnded() }
                )
            )
        case .notifications:
            NotificationsView()
        case .calendar:
            CalendarView(title: "Calendar")
        case .workoutDetail(let sessionID):
            WorkoutDetailView(sessionID: sessionID, stack: .home)
        case .workoutScreen(let sessionID):
            WorkoutScreenView(sessionID: sessionID, stack: .home)
        case .workoutCompletion(let planWorkoutID, _, let elapsedSeconds):
            WorkoutCompletionStubView(
                workoutName: workoutTitle(for: planWorkoutID),
                elapsedSeconds: elapsedSeconds
            )
        case .outdoorRunStub:
            MainTabPlaceholderView(
                title: "Outdoor Run",
                systemImage: "figure.run",
                message: "Outdoor run tracking arrives in a later update."
            )
        }
    }

    /// Profile prefers the live store (reflects M3-05 mutations) over the
    /// one-shot launch snapshot.
    private var profileState: RestoredUserState? {
        if let profile = planStore.profile {
            RestoredUserState(profile: profile, plan: planStore.plan)
        } else {
            restored
        }
    }

    private func workoutTitle(for planWorkoutID: UUID) -> String {
        guard let plan = planStore.plan,
              let session = PlanMutator.session(withID: planWorkoutID, in: plan)
        else {
            return "Workout"
        }
        return session.title
    }
}
