import SwiftData
import SwiftUI

/// Recipe root shell (M7-08 / SPEC §12): Day | Explore tabs (Insights chip
/// picker spirit), calendar day suggestions, and Explore filters.
struct RecipeView: View {
    @Environment(MainRouter.self) private var router
    @Environment(\.mealDBClient) private var mealDBClient
    @Environment(PlanStore.self) private var planStore
    @Environment(SupabaseAuthService.self) private var authService
    @Environment(SupabaseSyncEngine.self) private var syncEngine
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: RecipePrimaryTab = .day
    @State private var dayViewModel: RecipeDayViewModel?
    @State private var exploreViewModel: RecipeExploreViewModel?

    var body: some View {
        Group {
            if let dayViewModel, let exploreViewModel {
                tabContent(dayViewModel: dayViewModel, exploreViewModel: exploreViewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PluriColor.bgCanvas)
        .navigationTitle("Recipe")
        .onAppear {
            ensureViewModels()
        }
    }

    @ViewBuilder
    private func tabContent(
        dayViewModel: RecipeDayViewModel,
        exploreViewModel: RecipeExploreViewModel
    ) -> some View {
        VStack(spacing: 0) {
            RecipePrimaryTabPicker(selectedTab: $selectedTab)
                .padding(.horizontal, PluriSpacing.lg)
                .padding(.top, PluriSpacing.sm)

            switch selectedTab {
            case .day:
                RecipeDayView(viewModel: dayViewModel) { recipe in
                    router.openRecipeDetail(mealID: recipe.id)
                }
            case .explore:
                RecipeExploreView(viewModel: exploreViewModel) { recipe in
                    router.openRecipeDetail(mealID: recipe.id)
                }
            }
        }
    }

    private func ensureViewModels() {
        let userId = authService.appUserID.flatMap(UUID.init(uuidString:)) ?? UUID()

        if dayViewModel == nil {
            dayViewModel = RecipeDayViewModel(
                mealDBClient: mealDBClient,
                planStore: planStore,
                modelContext: modelContext,
                userId: userId,
                syncEngine: syncEngine
            )
        }
        if exploreViewModel == nil {
            exploreViewModel = RecipeExploreViewModel(mealDBClient: mealDBClient)
        }
    }
}

// MARK: - Tab picker

private struct RecipePrimaryTabPicker: View {
    @Binding var selectedTab: RecipePrimaryTab

    var body: some View {
        HStack(spacing: PluriSpacing.sm) {
            ForEach(RecipePrimaryTab.allCases) { tab in
                PluriChip(
                    title: LocalizedStringKey(tab.title),
                    isSelected: tab == selectedTab
                ) {
                    selectedTab = tab
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recipe tabs")
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Schema([
            RecipeFavoriteRecord.self,
            RecipeDaySuggestionsRecord.self,
            RecipeCandidatePoolRecord.self,
        ]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    NavigationStack {
        RecipeView()
    }
    .environment(MainRouter())
    .environment(\.mealDBClient, MockMealDBClient())
    .environment(PlanStore(mutationService: MockPlanMutationService()))
    .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
    .environment(
        SupabaseSyncEngine(
            modelContext: container.mainContext,
            supabaseService: SupabaseService()
        )
    )
    .modelContainer(container)
}
