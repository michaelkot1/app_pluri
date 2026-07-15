import SwiftUI

/// Q10 (M1-13) — session duration, single-select.
struct Q10DurationView: View {
    @Bindable var answers: OnboardingAnswers
    var progress: Double?
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            title: "How much time do you want to devote each workout?",
            onContinue: onContinue
        ) {
            PluriChipGrid(
                items: SessionDuration.allCases,
                isSelected: { answers.sessionDuration == $0 },
                label: \.title,
                action: { answers.sessionDuration = $0 }
            )
        }
    }
}

#Preview {
    NavigationStack {
        Q10DurationView(answers: OnboardingAnswers(), progress: 11.0 / 14, onContinue: {})
    }
}
