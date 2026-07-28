import SwiftUI

/// Q6 (M1-10) — equipment, multi-select from the WorkoutX list, grouped by
/// category. Pre-filled by Q5's auto-select mapping; free to edit from here.
struct Q6EquipmentView: View {
    @Bindable var answers: OnboardingAnswers
    var progress: Double?
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            title: "What equipment is available to you?",
            subtitle: "We pre-selected some based on where you work out — feel free to adjust.",
            isContinueEnabled: !answers.equipment.isEmpty,
            onContinue: onContinue
        ) {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                ForEach(EquipmentCatalog.categories) { category in
                    EquipmentCategorySection(
                        category: category,
                        isSelected: { answers.equipment.contains($0) },
                        action: toggle
                    )
                }
            }
        }
    }

    private func toggle(_ item: String) {
        if answers.equipment.contains(item) {
            answers.equipment.remove(item)
        } else {
            answers.equipment.insert(item)
        }
    }
}

/// One labeled equipment group with full-width multi-select rows.
private struct EquipmentCategorySection: View {
    let category: EquipmentCategory
    var isSelected: (String) -> Bool
    var action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text(category.title)
                .font(PluriFont.overline)
                .foregroundStyle(PluriColor.textSecondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)

            OnboardingSelectRowList(
                items: category.items,
                isSelected: isSelected,
                label: { $0 },
                action: action
            )
        }
    }
}

#Preview {
    NavigationStack {
        Q6EquipmentView(answers: OnboardingAnswers(), progress: 7.0 / 14, onContinue: {})
    }
}
