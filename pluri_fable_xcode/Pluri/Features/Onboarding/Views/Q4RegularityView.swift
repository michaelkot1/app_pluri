import SwiftUI

/// Q4 (M1-09) — training regularity, single-select.
/// Defaults to `.onAndOff`.
struct Q4RegularityView: View {
    @Bindable var answers: OnboardingAnswers
    var progress: Double?
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            title: "Do you weight train regularly?",
            onContinue: onContinue
        ) {
            OnboardingSelectRowList(
                items: RegularityLevel.allCases,
                isSelected: { answers.regularity == $0 },
                label: \.title,
                action: { answers.regularity = $0 }
            )
        }
    }
}

#Preview {
    NavigationStack {
        Q4RegularityView(answers: OnboardingAnswers(), progress: 5.0 / 14, onContinue: {})
    }
}
