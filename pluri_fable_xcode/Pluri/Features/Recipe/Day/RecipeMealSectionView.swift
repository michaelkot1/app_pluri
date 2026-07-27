import SwiftUI

/// One meal-slot section on Recipe Day (~3 suggestion cards).
struct RecipeMealSectionView: View {
    var slot: MealSlot
    var recipes: [MealDBRecipe]
    var onSelect: (MealDBRecipe) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text(slot.displayTitle)
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if recipes.isEmpty {
                Text("No allergy-safe options for \(slot.displayTitle.lowercased()) today.")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
                    .accessibilityLabel("No \(slot.displayTitle) suggestions")
            } else {
                VStack(spacing: PluriSpacing.sm) {
                    ForEach(recipes) { recipe in
                        RecipeSuggestionCard(recipe: recipe) {
                            onSelect(recipe)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

/// Compact suggestion row — pink food accent, navigates to detail.
struct RecipeSuggestionCard: View {
    var recipe: MealDBRecipe
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PluriSpacing.md) {
                recipeThumb
                VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                    Text(recipe.name)
                        .font(PluriFont.body)
                        .foregroundStyle(PluriColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let area = recipe.area, !area.isEmpty {
                        Text(area)
                            .font(PluriFont.overline)
                            .foregroundStyle(PluriColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textTertiary)
            }
            .padding(PluriSpacing.md)
            .frame(minHeight: 44)
            .background(PluriColor.bgSurface, in: .rect(cornerRadius: PluriRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: PluriRadius.md)
                    .strokeBorder(PluriColor.accentPink.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recipe.name)
        .accessibilityHint("Opens recipe details")
    }

    @ViewBuilder
    private var recipeThumb: some View {
        Group {
            if let url = recipe.thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        thumbPlaceholder
                    }
                }
            } else {
                thumbPlaceholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(.rect(cornerRadius: PluriRadius.sm))
        .accessibilityHidden(true)
    }

    private var thumbPlaceholder: some View {
        ZStack {
            PluriColor.bgMuted
            Image(systemName: "fork.knife")
                .foregroundStyle(PluriColor.accentPink)
        }
    }
}

extension MealSlot {
    var displayTitle: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .dessert: "Dessert"
        }
    }
}

#Preview("Populated") {
    RecipeMealSectionView(
        slot: .lunch,
        recipes: Array([MealDBRecipe].mealDBPreviewFixtures.prefix(2)),
        onSelect: { _ in }
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}

#Preview("Empty") {
    RecipeMealSectionView(slot: .dessert, recipes: [], onSelect: { _ in })
        .padding(PluriSpacing.lg)
        .background(PluriColor.bgCanvas)
}
