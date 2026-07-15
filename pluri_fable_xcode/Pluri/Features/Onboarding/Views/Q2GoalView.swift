import SwiftUI

/// Q2 (M1-09) — main goal, single-select.
struct Q2GoalView: View {
    @Bindable var answers: OnboardingAnswers
    var progress: Double?
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            title: "What's your main goal?",
            isContinueEnabled: answers.goal != nil,
            onContinue: onContinue
        ) {
            PluriChipGrid(
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
