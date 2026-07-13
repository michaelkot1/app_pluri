import SwiftUI

/// Q13 (M1-15) — start date: Today / Tomorrow / a chosen date.
struct Q13StartDateView: View {
    @Bindable var answers: OnboardingAnswers
    var progress: Double?
    var onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            title: "When do you want to start?",
            onContinue: onContinue
        ) {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                PluriChipGrid(
                    items: StartDateOption.allCases,
                    isSelected: { answers.startDateOption == $0 },
                    label: \.title,
                    action: { answers.startDateOption = $0 }
                )

                if answers.startDateOption == .custom {
                    DatePicker(
                        "Start date",
                        selection: $answers.customStartDate,
                        in: Date.now...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(PluriColor.brandOrange)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        Q13StartDateView(answers: OnboardingAnswers(), progress: 14.0 / 14, onContinue: {})
    }
}
