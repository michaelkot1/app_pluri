import SwiftUI

/// Home tab placeholder (M2-18): greets the user, teases the restored / freshly
/// unlocked plan, and keeps Profile reachable from the top bar (SPEC §5).
/// Calendar strip, Pluri Score, and health tiles arrive in M3+.
///
/// Plan content observes the shared `PlanStore` (M3-04) so calendar / manage
/// mutations reflect here immediately; the one-shot `restored` value is kept
/// only for the Profile flow's needs.
struct HomePlaceholderView: View {
    var restored: RestoredUserState?
    /// Root reroute after sign-out / account deletion from Profile (M2-17).
    var onAccountEnded: @MainActor @Sendable () -> Void = {}

    @Environment(SupabaseAuthService.self) private var authService
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(PlanStore.self) private var planStore

    @State private var showsProfile = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                Text(subtitle)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)

                if let plan = planStore.plan {
                    PlanSummaryCard(plan: plan)
                    if let firstSession = plan.firstSession {
                        PlanFirstSessionCard(session: firstSession)
                    }
                } else if planStore.loadState == .failed {
                    restoreFailedCard
                } else {
                    noPlanCard
                }
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .background(PluriColor.bgCanvas)
        .navigationTitle(greeting)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Profile", systemImage: "person.crop.circle") {
                    showsProfile = true
                }
                .foregroundStyle(PluriColor.brandOrange)
            }
        }
        .navigationDestination(isPresented: $showsProfile) {
            ProfileView(
                restored: restored,
                viewModel: ProfileViewModel(
                    authService: authService,
                    subscriptionService: subscriptionService,
                    onAccountEnded: { onAccountEnded() }
                )
            )
        }
    }

    private var greeting: String {
        if let name = planStore.profile?.displayName ?? restored?.profile.displayName, !name.isEmpty {
            "Hi, \(name)"
        } else {
            "Home"
        }
    }

    private var subtitle: String {
        if planStore.plan != nil {
            "Your plan is ready on this device. Workouts, score, and health tiles land here soon."
        } else {
            "You’re all set. Workouts, score, and health tiles land here soon."
        }
    }

    private var noPlanCard: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("No active plan yet")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)
                Text("We couldn’t find an active plan on your account. Plan tools arrive with the next update.")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var restoreFailedCard: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("We couldn’t load your plan")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)
                Text("Check your connection and relaunch — your plan is safe on your account.")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        HomePlaceholderView(restored: nil)
    }
    .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
    .environment(SubscriptionService(configurePurchases: false))
    .environment(PlanStore(mutationService: MockPlanMutationService()))
    .environment(ThemeStore())
}
