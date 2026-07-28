import SwiftUI

/// Q2 (M1-09) — main goal, single-select. Defaults to `.generalFitness`.
struct Q2GoalView: View {
    @Bindable var answers: OnboardingAnswers
    var progress: Double?
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            title: "What's your main goal?",
            onContinue: onContinue
        ) {
            OnboardingSelectRowList(
                items: Goal.allCases,
                isSelected: { answers.goal == $0 },
                label: \.title,
                action: { answers.goal = $0 }
            )
        }
    }
}

#Preview {
    NavigationStack {
        Q2GoalView(answers: OnboardingAnswers(), progress: 3.0 / 14, onContinue: {})
    }
}
