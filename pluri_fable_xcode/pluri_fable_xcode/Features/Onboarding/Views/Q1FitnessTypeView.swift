import SwiftUI

/// Q1 (M1-08) — fitness type. Only `.workout` is selectable in v1; cardio
/// and flexibility are visible but disabled with a "coming soon" label
/// (SPEC §1.1 / §3.2).
struct Q1FitnessTypeView: View {
    @Bindable var answers: OnboardingAnswers
    var progress: Double?
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            title: "What type of fitness would you like to do?",
            onContinue: onContinue
        ) {
            PluriChipGrid(
                items: FitnessType.allCases,
                isSelected: { answers.fitnessType == $0 },
                isEnabled: \.isAvailable,
                label: { $0.isAvailable ? $0.title : "\($0.title) · Coming soon" },
                action: { answers.fitnessType = $0 }
            )
        }
    }
}

#Preview {
    NavigationStack {
        Q1FitnessTypeView(answers: OnboardingAnswers(), progress: 2.0 / 14, onContinue: {})
    }
}
