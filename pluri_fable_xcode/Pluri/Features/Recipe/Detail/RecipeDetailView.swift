import SwiftData
import SwiftUI

/// Recipe detail (M7-09/12 / SPEC §12): MealDB content, favorite toggle,
/// shared Log sheet with recipe prefill.
struct RecipeDetailView: View {
    var mealID: String
    var seedRecipe: MealDBRecipe?

    @Environment(\.mealDBClient) private var mealDBClient
    @Environment(\.nutritionClient) private var nutritionClient
    @Environment(SupabaseAuthService.self) private var authService
    @Environment(SupabaseSyncEngine.self) private var syncEngine
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: RecipeDetailViewModel?
    @State private var foodLoggingViewModel: FoodLoggingViewModel?

    var body: some View {
        Group {
            if let viewModel {
                RecipeDetailContent(
                    viewModel: viewModel,
                    foodLoggingViewModel: $foodLoggingViewModel,
                    makeLoggingViewModel: makeLoggingViewModel
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PluriColor.bgCanvas)
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            ensureViewModel()
            await viewModel?.load()
        }
    }

    private func ensureViewModel() {
        guard viewModel == nil else { return }
        let userId = authService.appUserID.flatMap(UUID.init(uuidString:))
        viewModel = RecipeDetailViewModel(
            mealID: mealID,
            mealDBClient: mealDBClient,
            modelContext: modelContext,
            userId: userId,
            syncEngine: syncEngine,
            seedRecipe: seedRecipe
        )
    }

    private func makeLoggingViewModel(context: FoodLoggingContext) -> FoodLoggingViewModel {
        let userId = authService.appUserID.flatMap(UUID.init(uuidString:)) ?? UUID()
        let store = FoodLogsStore(
            modelContext: modelContext,
            userId: userId,
            syncEngine: syncEngine
        )
        return FoodLoggingViewModel(
            context: context,
            nutritionClient: nutritionClient,
            foodLogsStore: store
        )
    }
}

private struct RecipeDetailContent: View {
    @Bindable var viewModel: RecipeDetailViewModel
    @Binding var foodLoggingViewModel: FoodLoggingViewModel?
    var makeLoggingViewModel: (FoodLoggingContext) -> FoodLoggingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                switch viewModel.loadState {
                case .idle, .loading:
                    ProgressView("Loading recipe…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PluriSpacing.xl)
                case .offline:
                    HomeMessageCard(
                        title: "Recipe needs a connection",
                        message: "Connect to the internet to load this recipe's full details."
                    )
                    .padding(.horizontal, PluriSpacing.lg)
                case .error(let message):
                    HomeMessageCard(
                        title: "Couldn't load recipe",
                        message: message
                    )
                    .padding(.horizontal, PluriSpacing.lg)
                case .loaded:
                    if let recipe = viewModel.recipe {
                        RecipeDetailBody(
                            recipe: recipe,
                            isFavorite: viewModel.isFavorite,
                            onToggleFavorite: { viewModel.toggleFavorite() },
                            onLog: { presentLog() }
                        )
                    }
                }
            }
            .padding(.vertical, PluriSpacing.md)
        }
        .scrollIndicators(.hidden)
        .sheet(
            isPresented: Binding(
                get: { viewModel.isPresentingLogSheet },
                set: { presented in
                    if presented {
                        presentLog()
                    } else {
                        viewModel.dismissLog()
                        foodLoggingViewModel = nil
                    }
                }
            )
        ) {
            if let foodLoggingViewModel {
                FoodLoggingSheet(viewModel: foodLoggingViewModel) {
                    viewModel.dismissLog()
                }
            }
        }
    }

    private func presentLog() {
        guard let context = viewModel.foodLoggingContext else { return }
        foodLoggingViewModel = makeLoggingViewModel(context)
        viewModel.openLog()
    }
}

private struct RecipeDetailBody: View {
    var recipe: MealDBRecipe
    var isFavorite: Bool
    var onToggleFavorite: () -> Void
    var onLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.lg) {
            hero
                .padding(.horizontal, PluriSpacing.lg)

            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text(recipe.name)
                    .font(PluriFont.title)
                    .foregroundStyle(PluriColor.textPrimary)
                metadataRow
            }
            .padding(.horizontal, PluriSpacing.lg)
            .accessibilityElement(children: .combine)

            actionRow
                .padding(.horizontal, PluriSpacing.lg)

            if !recipe.ingredients.isEmpty {
                ingredientsSection
                    .padding(.horizontal, PluriSpacing.lg)
            }

            if let instructions = recipe.instructions, !instructions.isEmpty {
                instructionsSection(instructions)
                    .padding(.horizontal, PluriSpacing.lg)
            }
        }
    }

    @ViewBuilder
    private var hero: some View {
        Group {
            if let url = recipe.thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        heroPlaceholder
                    }
                }
            } else {
                heroPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(.rect(cornerRadius: PluriRadius.lg))
        .accessibilityHidden(true)
    }

    private var heroPlaceholder: some View {
        ZStack {
            PluriColor.bgMuted
            Image(systemName: "fork.knife")
                .font(PluriFont.title)
                .foregroundStyle(PluriColor.accentPink)
        }
    }

    private var metadataRow: some View {
        HStack(spacing: PluriSpacing.sm) {
            if let category = recipe.category, !category.isEmpty {
                Text(category)
                    .font(PluriFont.overline)
                    .foregroundStyle(PluriColor.statusBlue)
            }
            if let area = recipe.area, !area.isEmpty {
                Text(area)
                    .font(PluriFont.overline)
                    .foregroundStyle(PluriColor.textSecondary)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: PluriSpacing.sm) {
            Button(
                isFavorite ? "Favorited" : "Favorite",
                systemImage: isFavorite ? "heart.fill" : "heart"
            ) {
                onToggleFavorite()
            }
            .buttonStyle(.borderedProminent)
            .tint(PluriColor.accentPink)
            .frame(minHeight: 44)

            Button("Log", systemImage: "plus.circle") {
                onLog()
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
            .accessibilityHint("Log this recipe as a food")

            Spacer(minLength: 0)
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text("Ingredients")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
                HStack(alignment: .top, spacing: PluriSpacing.sm) {
                    Text(ingredient.measure)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.statusBlue)
                        .frame(minWidth: 72, alignment: .leading)
                    Text(ingredient.name)
                        .font(PluriFont.body)
                        .foregroundStyle(PluriColor.textPrimary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func instructionsSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text("Instructions")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(text)
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)
        }
    }
}

#Preview("Not favorited") {
    ScrollView {
        RecipeDetailBody(
            recipe: [MealDBRecipe].mealDBPreviewFixtures[0],
            isFavorite: false,
            onToggleFavorite: {},
            onLog: {}
        )
        .padding(.vertical, PluriSpacing.md)
    }
    .scrollIndicators(.hidden)
    .background(PluriColor.bgCanvas)
}

#Preview("Favorited") {
    ScrollView {
        RecipeDetailBody(
            recipe: [MealDBRecipe].mealDBPreviewFixtures[0],
            isFavorite: true,
            onToggleFavorite: {},
            onLog: {}
        )
        .padding(.vertical, PluriSpacing.md)
    }
    .scrollIndicators(.hidden)
    .background(PluriColor.bgCanvas)
}
