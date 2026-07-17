import SwiftUI

/// Resolves a pushed `HomeRoute` to its destination view (M3-06). Profile is
/// the real M2-16 screen fed from the live `PlanStore` (falling back to the
/// launch-restored state), Calendar is the real M3-13 page, and Notifications
/// is the real M3-15 page; Workout Detail and Outdoor Run are honest stubs
/// until M4.
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
            WorkoutDetailStubView(session: session(withID: sessionID))
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

    private func session(withID id: UUID) -> PlannedSession? {
        guard let plan = planStore.plan else { return nil }
        return PlanMutator.session(withID: id, in: plan)
    }
}
