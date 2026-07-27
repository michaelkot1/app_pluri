import SwiftUI

/// Explore tab (M7-10 / SPEC §12): cuisine, protein, duration, portion filters
/// with PluriChip UI and honest empty / offline / error states.
struct RecipeExploreView: View {
    @Bindable var viewModel: RecipeExploreViewModel
    var onSelectRecipe: (MealDBRecipe) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                filterSection(
                    title: "Cuisine",
                    accessibilityLabel: "Cuisine filters"
                ) {
                    ForEach(RecipeExploreCuisine.allCases) { value in
                        PluriChip(
                            title: LocalizedStringKey(value.title),
                            isSelected: viewModel.filters.cuisine == value
                        ) {
                            viewModel.setCuisine(value)
                        }
                    }
                }

                filterSection(
                    title: "Protein",
                    accessibilityLabel: "Protein filters"
                ) {
                    ForEach(RecipeExploreProtein.allCases) { value in
                        PluriChip(
                            title: LocalizedStringKey(value.title),
                            isSelected: viewModel.filters.protein == value
                        ) {
                            viewModel.setProtein(value)
                        }
                    }
                }

                filterSection(
                    title: "Duration",
                    accessibilityLabel: "Duration filters"
                ) {
                    ForEach(RecipeExploreDuration.allCases) { value in
                        PluriChip(
                            title: LocalizedStringKey(value.title),
                            isSelected: viewModel.filters.duration == value
                        ) {
                            viewModel.setDuration(value)
                        }
                    }
                }

                filterSection(
                    title: "Portion",
                    accessibilityLabel: "Portion filters"
                ) {
                    ForEach(RecipeExplorePortion.allCases) { value in
                        PluriChip(
                            title: LocalizedStringKey(value.title),
                            isSelected: viewModel.filters.portion == value
                        ) {
                            viewModel.setPortion(value)
                        }
                    }
                }

                resultsSection
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.md)
        }
        .scrollIndicators(.hidden)
        .task {
            if viewModel.loadState == .idle {
                viewModel.reload()
            }
        }
    }

    private func filterSection<Content: View>(
        title: String,
        accessibilityLabel: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text(title)
                .font(PluriFont.overline)
                .foregroundStyle(PluriColor.textSecondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal) {
                HStack(spacing: PluriSpacing.sm) {
                    content()
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text("Results")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            switch viewModel.loadState {
            case .idle, .loading:
                ProgressView("Searching recipes…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PluriSpacing.xl)
                    .accessibilityLabel("Searching recipes")
            case .offline:
                HomeMessageCard(
                    title: "Explore needs a connection",
                    message: "Connect to the internet to browse and filter recipes. Saved favorites still work offline."
                )
            case .error(let message):
                HomeMessageCard(
                    title: "Couldn't search recipes",
                    message: message
                )
            case .empty:
                HomeMessageCard(
                    title: "No recipes match",
                    message: "Try loosening a filter — cuisine, protein, time, or portion."
                )
            case .loaded:
                VStack(spacing: PluriSpacing.sm) {
                    ForEach(viewModel.results) { recipe in
                        RecipeSuggestionCard(recipe: recipe) {
                            onSelectRecipe(recipe)
                        }
                    }
                }
            }
        }
    }
}

#Preview("Online") {
    let vm = RecipeExploreViewModel(
        mealDBClient: MockMealDBClient(),
        reachability: AlwaysOnlineReachability()
    )
    NavigationStack {
        RecipeExploreView(viewModel: vm, onSelectRecipe: { _ in })
    }
    .background(PluriColor.bgCanvas)
}

#Preview("Offline") {
    let vm = RecipeExploreViewModel(
        mealDBClient: MockMealDBClient(),
        reachability: MockNetworkReachability(isOnline: false)
    )
    NavigationStack {
        RecipeExploreView(viewModel: vm, onSelectRecipe: { _ in })
    }
    .background(PluriColor.bgCanvas)
}
