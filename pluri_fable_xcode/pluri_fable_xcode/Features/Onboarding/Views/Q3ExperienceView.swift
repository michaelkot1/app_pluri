import SwiftUI

/// Q3 (M1-09) — weight-training experience, single-select.
struct Q3ExperienceView: View {
    @Bindable var answers: OnboardingAnswers
    var progress: Double?
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            title: "How long have you been weight training?",
            isContinueEnabled: answers.experience != nil,
            onContinue: onContinue
        ) {
            PluriChipGrid(
                items: ExperienceLevel.allCases,
                isSelected: { answers.experience == $0 },
                label: \.title,
                action: { answers.experience = $0 }
            )
        }
    }
}

#Preview {
    NavigationStack {
        Q3ExperienceView(answers: OnboardingAnswers(), progress: 4.0 / 14, onContinue: {})
    }
}
