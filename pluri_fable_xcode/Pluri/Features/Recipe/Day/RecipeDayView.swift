import SwiftData
import SwiftUI

/// Recipe Day shell (M7-08 / M7-11 / SPEC §12): calendar strip, calorie ring,
/// breakfast/lunch/dinner/dessert suggestion sections with honest empty/
/// offline/error states.
struct RecipeDayView: View {
    @Bindable var viewModel: RecipeDayViewModel
    var onSelectRecipe: (MealDBRecipe) -> Void

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var selectedDay: Date { viewModel.resolvedSelectedDay(today: today) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                RecipeCalendarStrip(
                    days: viewModel.monthDays(containing: selectedDay),
                    selectedDay: selectedDay,
                    today: today,
                    onSelect: { viewModel.select(day: $0) }
                )

                Text(selectedDay, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(PluriFont.title)
                    .foregroundStyle(PluriColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                DayCalorieRingView(progress: viewModel.calorieProgress)

                statusContent

                if showsMealSections {
                    ForEach(MealSlot.allCases, id: \.self) { slot in
                        RecipeMealSectionView(
                            slot: slot,
                            recipes: viewModel.suggestions[slot],
                            onSelect: onSelectRecipe
                        )
                    }
                }
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.md)
        }
        .scrollIndicators(.hidden)
        .task {
            viewModel.reload()
        }
        // Refresh ring when returning from recipe detail after a Log save
        // (detail sheet has no access to this dayViewModel; standalone Log
        // already refreshes via RecipeView onSaved/onDismiss).
        .onAppear {
            viewModel.refreshCalorieProgress()
        }
    }

    private var showsMealSections: Bool {
        switch viewModel.loadState {
        case .loaded, .empty, .offlineCached:
            true
        case .idle, .loading, .offlineNoCache, .error:
            false
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            ProgressView("Loading recipes…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, PluriSpacing.xl)
                .accessibilityLabel("Loading recipes")
        case .loaded:
            EmptyView()
        case .empty:
            HomeMessageCard(
                title: "No suggestions today",
                message: "We couldn't find allergy-safe recipes for this day. Try Explore, or check back tomorrow."
            )
        case .offlineCached:
            HomeMessageCard(
                title: "Showing saved suggestions",
                message: "You're offline — these are the last recipes we saved for this day."
            )
        case .offlineNoCache:
            HomeMessageCard(
                title: "Recipes need a connection",
                message: "Connect to the internet to load today's suggestions. Favorites you already saved still work offline."
            )
        case .error(let message):
            HomeMessageCard(
                title: "Couldn't load recipes",
                message: message
            )
        }
    }
}

#Preview("Populated") {
    let container = try! ModelContainer(
        for: Schema([
            RecipeFavoriteRecord.self,
            FoodLogRecord.self,
            RecipeDaySuggestionsRecord.self,
            RecipeCandidatePoolRecord.self,
        ]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let userId = UUID()
    let planStore = PlanStore(mutationService: MockPlanMutationService())
    let vm = RecipeDayViewModel(
        mealDBClient: MockMealDBClient(),
        planStore: planStore,
        modelContext: container.mainContext,
        userId: userId,
        reachability: AlwaysOnlineReachability()
    )
    NavigationStack {
        RecipeDayView(viewModel: vm, onSelectRecipe: { _ in })
    }
    .background(PluriColor.bgCanvas)
    .modelContainer(container)
}

#Preview("Offline") {
    let container = try! ModelContainer(
        for: Schema([
            RecipeFavoriteRecord.self,
            FoodLogRecord.self,
            RecipeDaySuggestionsRecord.self,
            RecipeCandidatePoolRecord.self,
        ]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let vm = RecipeDayViewModel(
        mealDBClient: MockMealDBClient(),
        planStore: PlanStore(mutationService: MockPlanMutationService()),
        modelContext: container.mainContext,
        userId: UUID(),
        reachability: MockNetworkReachability(isOnline: false)
    )
    NavigationStack {
        RecipeDayView(viewModel: vm, onSelectRecipe: { _ in })
    }
    .background(PluriColor.bgCanvas)
    .modelContainer(container)
}

#Preview("Empty") {
    let container = try! ModelContainer(
        for: Schema([
            RecipeFavoriteRecord.self,
            FoodLogRecord.self,
            RecipeDaySuggestionsRecord.self,
            RecipeCandidatePoolRecord.self,
        ]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let vm = RecipeDayViewModel(
        mealDBClient: MockMealDBClient(fixtures: []),
        planStore: PlanStore(mutationService: MockPlanMutationService()),
        modelContext: container.mainContext,
        userId: UUID(),
        reachability: AlwaysOnlineReachability()
    )
    NavigationStack {
        RecipeDayView(viewModel: vm, onSelectRecipe: { _ in })
    }
    .background(PluriColor.bgCanvas)
    .modelContainer(container)
}
