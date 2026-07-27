import SwiftData
import SwiftUI

/// Shared food logging sheet (M7-11/12) — Nutrition search, serving = query,
/// meal tag, nil-kcal honesty. Used from Recipe Day (standalone) and detail.
struct FoodLoggingSheet: View {
    @Bindable var viewModel: FoodLoggingViewModel
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PluriSpacing.md) {
                    if let recipeTitle = viewModel.recipeTitle {
                        Text("Logging \(recipeTitle)")
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textSecondary)
                    }

                    searchField
                    mealPicker
                    statusContent
                    resultsList

                    if let message = viewModel.saveErrorMessage {
                        Text(message)
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textSecondary)
                            .accessibilityLabel(message)
                    }

                    Button("Save log") {
                        if viewModel.save() {
                            onSaved()
                            dismiss()
                        }
                    }
                    .buttonStyle(.pluriPrimary)
                    .frame(minHeight: 44)
                    .disabled(!viewModel.canSave)
                    .accessibilityHint(
                        viewModel.canSave
                            ? "Saves this food to today's log"
                            : "Select a food that includes calories to save"
                    )
                }
                .padding(PluriSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .background(PluriColor.bgSurface)
            .navigationTitle("Log food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                viewModel.prepareInitialSearchIfNeeded()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(PluriRadius.xl)
        .presentationBackground(PluriColor.bgSurface)
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
            Text("Food & serving")
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
            TextField("e.g. 1 cup rice", text: $viewModel.searchQuery)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: viewModel.searchQuery) { _, _ in
                    viewModel.onSearchQueryChanged()
                }
                .accessibilityHint("Search includes the serving size, like MyFitnessPal")
        }
    }

    private var mealPicker: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
            Text("Meal")
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
            ScrollView(.horizontal) {
                HStack(spacing: PluriSpacing.sm) {
                    ForEach(FoodLogMeal.allCases) { meal in
                        PluriChip(
                            title: LocalizedStringKey(meal.displayTitle),
                            isSelected: viewModel.meal == meal
                        ) {
                            viewModel.meal = meal
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .accessibilityLabel("Meal tag")
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch viewModel.searchState {
        case .idle:
            Text("Search for a food and serving — for example, “100g chicken breast”.")
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)
        case .searching:
            ProgressView("Searching…")
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Searching foods")
        case .empty:
            Text("No foods matched that search. Try a different name or serving.")
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)
        case .offline:
            HomeMessageCard(
                title: "Food search needs a connection",
                message: "Connect to the internet to look up nutrition. You can still see foods you’ve already logged for this day."
            )
        case .error(let message):
            HomeMessageCard(
                title: "Couldn't search foods",
                message: message
            )
        case .results:
            EmptyView()
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        if viewModel.searchState == .results || !viewModel.results.isEmpty {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("Results")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                ForEach(viewModel.results) { food in
                    FoodSearchResultRow(
                        food: food,
                        isSelected: viewModel.selectedFood?.id == food.id
                    ) {
                        viewModel.selectFood(food)
                    }
                }
            }
        }
    }
}

private struct FoodSearchResultRow: View {
    var food: NutritionFood
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: PluriSpacing.md) {
                VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                    Text(food.name)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textPrimary)
                    Text(servingSubtitle)
                        .font(PluriFont.overline)
                        .foregroundStyle(PluriColor.textSecondary)
                }
                Spacer(minLength: 0)
                Text(caloriesLabel)
                    .font(PluriFont.label)
                    .foregroundStyle(
                        food.calories == nil
                            ? PluriColor.textTertiary
                            : PluriColor.statusBlue
                    )
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(PluriColor.brandOrange)
                }
            }
            .padding(PluriSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                PluriColor.bgMuted,
                in: .rect(cornerRadius: PluriRadius.md)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(accessibilityLabel)
    }

    private var servingSubtitle: String {
        let grams = food.servingSizeGrams.formatted(.number.precision(.fractionLength(0...1)))
        return "\(grams) g serving"
    }

    private var caloriesLabel: String {
        if let calories = food.calories {
            return "\(Int(calories.rounded()).formatted()) kcal"
        }
        return "Calories unavailable"
    }

    private var accessibilityLabel: String {
        "\(food.name), \(servingSubtitle), \(caloriesLabel)"
    }
}

// MARK: - Previews (M7-14)

#Preview("Idle") {
    FoodLoggingSheetPreviewHost(mode: .idle)
}

#Preview("Results") {
    FoodLoggingSheetPreviewHost(mode: .results)
}

#Preview("Nil kcal selected") {
    FoodLoggingSheetPreviewHost(mode: .nilKcal)
}

#Preview("Offline") {
    FoodLoggingSheetPreviewHost(mode: .offline)
}

private enum FoodLoggingSheetPreviewMode {
    case idle
    case results
    case nilKcal
    case offline
}

private struct FoodLoggingSheetPreviewHost: View {
    var mode: FoodLoggingSheetPreviewMode

    @State private var viewModel: FoodLoggingViewModel
    private let container: ModelContainer

    init(mode: FoodLoggingSheetPreviewMode) {
        self.mode = mode
        let container = try! ModelContainer(
            for: Schema([FoodLogRecord.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        self.container = container
        let store = FoodLogsStore(
            modelContext: container.mainContext,
            userId: UUID(),
            syncEngine: MockSyncEngine()
        )
        let reachability: any NetworkReachability =
            mode == .offline
            ? MockNetworkReachability(isOnline: false)
            : AlwaysOnlineReachability()
        let vm = FoodLoggingViewModel(
            context: .standalone(loggedDate: .now, meal: .lunch),
            nutritionClient: MockNutritionClient(),
            foodLogsStore: store,
            reachability: reachability
        )
        if mode == .nilKcal {
            vm.searchQuery = "1 lb brisket"
            if let brisket = [NutritionFood].nutritionPreviewFixtures.first(where: { $0.calories == nil }) {
                vm.selectFood(brisket)
            }
        }
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        FoodLoggingSheet(viewModel: viewModel, onSaved: {})
            .task {
                switch mode {
                case .idle, .nilKcal:
                    break
                case .results:
                    viewModel.searchQuery = "apple"
                    viewModel.onSearchQueryChanged()
                    try? await Task.sleep(for: .milliseconds(500))
                case .offline:
                    viewModel.searchQuery = "apple"
                    viewModel.onSearchQueryChanged()
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
            .modelContainer(container)
    }
}
