import SwiftUI

/// Q6 (M1-10) — equipment, multi-select from the WorkoutX list. Pre-filled
/// by Q5's auto-select mapping; free to edit from here.
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
            PluriChipGrid(
                items: EquipmentCatalog.all,
                isSelected: { answers.equipment.contains($0) },
                label: { $0 },
                action: { item in
                    if answers.equipment.contains(item) {
                        answers.equipment.remove(item)
                    } else {
                        answers.equipment.insert(item)
                    }
                }
            )
        }
    }
}

#Preview {
    NavigationStack {
        Q6EquipmentView(answers: OnboardingAnswers(), progress: 7.0 / 14, onContinue: {})
    }
}
