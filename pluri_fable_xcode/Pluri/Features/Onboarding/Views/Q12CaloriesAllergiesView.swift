import SwiftUI

/// Q12 (M1-14) — maintenance calories (from `CalorieCalculator`, using Q11's
/// answers) plus allergy chips with a search field for less common ones
/// (SPEC §3.2).
struct Q12CaloriesAllergiesView: View {
    @Bindable var answers: OnboardingAnswers
    var progress: Double?
    var onContinue: () -> Void

    @State private var searchText = ""

    private var searchResults: [String] {
        guard !searchText.isEmpty else { return [] }
        return AllergenCatalog.searchable.filter { $0.localizedStandardContains(searchText) }
    }

    private var otherSelectedAllergies: [String] {
        answers.allergies.subtracting(AllergenCatalog.common).sorted()
    }

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            title: "Your maintenance calories",
            onContinue: onContinue
        ) {
            VStack(alignment: .leading, spacing: PluriSpacing.xl) {
                calorieSummary

                VStack(alignment: .leading, spacing: PluriSpacing.md) {
                    Text("Do you have any allergies?")
                        .font(PluriFont.sectionHeader)
                        .foregroundStyle(PluriColor.textPrimary)

                    PluriChipGrid(
                        items: AllergenCatalog.common,
                        isSelected: { answers.allergies.contains($0) },
                        label: { $0 },
                        action: toggleAllergy
                    )

                    searchField

                    if !searchResults.isEmpty {
                        PluriChipGrid(
                            items: searchResults,
                            isSelected: { answers.allergies.contains($0) },
                            label: { $0 },
                            action: toggleAllergy
                        )
                    }

                    if !otherSelectedAllergies.isEmpty {
                        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                            Text("Also avoiding")
                                .font(PluriFont.label)
                                .foregroundStyle(PluriColor.textSecondary)
                            PluriChipGrid(
                                items: otherSelectedAllergies,
                                isSelected: { _ in true },
                                label: { $0 },
                                action: toggleAllergy
                            )
                        }
                    }
                }
            }
        }
    }

    private var calorieSummary: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("Based on your goals, your maintenance calories are")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
                if let calories = answers.maintenanceCalories {
                    HStack(alignment: .firstTextBaseline, spacing: PluriSpacing.xs) {
                        PluriHeroNumeral(text: calories.formatted())
                        Text("kcal / day")
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textSecondary)
                    }
                } else {
                    Text("Add your age, height, and weight on the previous screen to see this.")
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textTertiary)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: PluriSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PluriColor.textTertiary)
            TextField("Search for a specific allergy", text: $searchText)
                .font(PluriFont.body)
                .submitLabel(.done)
                .onSubmit(addCustomAllergyFromSearch)
        }
        .padding(PluriSpacing.md)
        .frame(minHeight: 44)
        .background(PluriColor.bgSurface, in: .rect(cornerRadius: PluriRadius.md))
    }

    private func toggleAllergy(_ allergy: String) {
        if answers.allergies.contains(allergy) {
            answers.allergies.remove(allergy)
        } else {
            answers.allergies.insert(allergy)
        }
    }

    private func addCustomAllergyFromSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        answers.allergies.insert(trimmed)
        searchText = ""
    }
}

#Preview {
    NavigationStack {
        Q12CaloriesAllergiesView(answers: OnboardingAnswers(), progress: 13.0 / 14, onContinue: {})
    }
}
