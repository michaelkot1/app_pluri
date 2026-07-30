import SwiftData
import SwiftUI

/// Main TabView navigation skeleton (M3-06 / M5-07 / M7-08 / M8-05): Home · Plan ·
/// Insights · Community · Recipe, one `NavigationStack` per tab, with a
/// `MainRouter` driving programmatic tab selection and typed route paths
/// (PLAN §1.2).
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
                NavigationStack(path: $router.planPath) {
                    PlanView()
                        .navigationDestination(for: PlanRoute.self) { route in
                            PlanRouteDestinationView(route: route)
                        }
                }
            }
            Tab("Insights", systemImage: "chart.line.uptrend.xyaxis", value: MainTab.insights) {
                NavigationStack(path: $router.insightsPath) {
                    InsightsView()
                        .navigationDestination(for: InsightsRoute.self) { route in
                            InsightsRouteDestinationView(route: route)
                        }
                }
            }
            Tab("Community", systemImage: "person.3.fill", value: MainTab.community) {
                NavigationStack(path: $router.communityPath) {
                    CommunityView()
                        .navigationDestination(for: CommunityRoute.self) { route in
                            CommunityRouteDestinationView(route: route)
                        }
                }
            }
            Tab("Recipe", systemImage: "fork.knife", value: MainTab.recipe) {
                NavigationStack(path: $router.recipePath) {
                    RecipeView()
                        .navigationDestination(for: RecipeRoute.self) { route in
                            RecipeRouteDestinationView(route: route)
                        }
                }
            }
        }
        .tint(PluriColor.brandOrange)
        .environment(router)
    }
}

#if DEBUG
#Preview {
    let container = try! ModelContainer(
        for: Schema([
            CachedExercise.self,
            ExerciseCatalogSyncState.self,
            WorkoutSessionRecord.self,
            SetLogRecord.self,
            RecipeFavoriteRecord.self,
            FoodLogRecord.self,
            RecipeDaySuggestionsRecord.self,
            RecipeCandidatePoolRecord.self,
        ]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    MainTabView(restored: nil)
        .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
        .environment(SubscriptionService(configurePurchases: false))
        .environment(HomePreviewData.readyStore())
        .environment(WorkoutReminderService.preview())
        .environment(LiveHealthKitService())
        .environment(ThemeStore())
        .environment(SwiftDataWorkoutSessionRepository(modelContext: container.mainContext))
        .environment(\.mealDBClient, MockMealDBClient())
        .environment(\.nutritionClient, MockNutritionClient())
        .environment(\.communityClient, MockCommunityClient())
        .modelContainer(container)
}
#endif
