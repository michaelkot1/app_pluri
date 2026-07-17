import SwiftUI

/// Main TabView navigation skeleton (M3-06): Home · Plan · Insights ·
/// Community · Recipe, one `NavigationStack` per tab, with a `MainRouter`
/// driving programmatic tab selection, the Home tab's typed route path, and
/// the health-tile deep link into Insights (PLAN §1.2). Plan / Community /
/// Recipe stay honest placeholders until their milestones.
struct MainTabView: View {
    /// Launch-restored profile + plan, kept as the Profile fallback.
    var restored: RestoredUserState?
    /// Root reroute after sign-out / account deletion from Profile (M2-17).
    var onAccountEnded: @MainActor @Sendable () -> Void = {}

    @State private var router = MainRouter()

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: MainTab.home) {
                NavigationStack(path: $router.homePath) {
                    HomeView()
                        .navigationDestination(for: HomeRoute.self) { route in
                            HomeRouteDestinationView(
                                route: route,
                                restored: restored,
                                onAccountEnded: { onAccountEnded() }
                            )
                        }
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
                    InsightsPlaceholderView()
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
        .environment(router)
    }
}

#Preview {
    MainTabView(restored: nil)
        .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
        .environment(SubscriptionService(configurePurchases: false))
        .environment(HomePreviewData.readyStore())
        .environment(ThemeStore())
}
