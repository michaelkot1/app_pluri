import SwiftUI

/// Minimal Main TabView shell (M2-18): Home · Plan · Insights · Community ·
/// Recipe, each with its own `NavigationStack`. Real tab content is M3+ —
/// placeholders stay honest about what's coming.
struct MainTabView: View {
    /// Restored (or just-flushed) profile + plan feeding Home and Profile.
    var restored: RestoredUserState?
    /// Root reroute after sign-out / account deletion from Profile (M2-17).
    var onAccountEnded: @MainActor @Sendable () -> Void = {}

    @State private var selection: MainTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house.fill", value: MainTab.home) {
                NavigationStack {
                    HomePlaceholderView(restored: restored, onAccountEnded: { onAccountEnded() })
                }
            }
            Tab("Plan", systemImage: "calendar", value: MainTab.plan) {
                NavigationStack {
                    MainTabPlaceholderView(
                        title: "Plan",
                        systemImage: "calendar",
                        message: "Your full plan, week cards, and calendar arrive in the next update."
                    )
                }
            }
            Tab("Insights", systemImage: "chart.line.uptrend.xyaxis", value: MainTab.insights) {
                NavigationStack {
                    MainTabPlaceholderView(
                        title: "Insights",
                        systemImage: "chart.line.uptrend.xyaxis",
                        message: "Performance trends and health insights are on their way."
                    )
                }
            }
            Tab("Community", systemImage: "person.3.fill", value: MainTab.community) {
                NavigationStack {
                    MainTabPlaceholderView(
                        title: "Community",
                        systemImage: "person.3.fill",
                        message: "Share wins and cheer others on — coming in a later update."
                    )
                }
            }
            Tab("Recipe", systemImage: "fork.knife", value: MainTab.recipe) {
                NavigationStack {
                    MainTabPlaceholderView(
                        title: "Recipe",
                        systemImage: "fork.knife",
                        message: "Daily recipe suggestions tuned to your goal arrive later."
                    )
                }
            }
        }
        .tint(PluriColor.brandOrange)
    }
}

#Preview {
    MainTabView(restored: nil)
        .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
        .environment(SubscriptionService(configurePurchases: false))
        .environment(PlanStore(mutationService: MockPlanMutationService()))
        .environment(ThemeStore())
}
