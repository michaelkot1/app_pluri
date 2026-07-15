import SwiftUI

/// Q8 (M1-12) — weekday picker, default Mon/Wed/Fri, enforcing 2–6 days
/// (SPEC §3.2).
struct Q8TrainingDaysView: View {
    @Bindable var answers: OnboardingAnswers
    var progress: Double?
    var onContinue: () -> Void

    private static let dayRange = 2...6

    private var isValid: Bool {
        Self.dayRange.contains(answers.trainingDays.count)
    }

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            title: "How often would you like to work out?",
            subtitle: "Pick between 2 and 6 days a week.",
            isContinueEnabled: isValid,
            onContinue: onContinue
        ) {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                PluriChipGrid(
                    items: Weekday.displayOrder,
                    isSelected: { answers.trainingDays.contains($0) },
                    label: \.shortTitle,
                    action: toggle
                )

                if !isValid {
                    Text("Choose between 2 and 6 days.")
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.statusRedSoft)
                }
            }
        }
    }

    private func toggle(_ day: Weekday) {
        if answers.trainingDays.contains(day) {
            answers.trainingDays.remove(day)
        } else {
            answers.trainingDays.insert(day)
        }
    }
}

#Preview {
    NavigationStack {
        Q8TrainingDaysView(answers: OnboardingAnswers(), progress: 9.0 / 14, onContinue: {})
    }
}
