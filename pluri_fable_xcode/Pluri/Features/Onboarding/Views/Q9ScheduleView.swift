import SwiftUI

/// Q9 (M1-12) — scheduled vs flexible, plus plan length in weeks (3–12,
/// suggested 6) per SPEC §3.2 / §14 decision #4.
struct Q9ScheduleView: View {
    @Bindable var answers: OnboardingAnswers
    var progress: Double?
    var onContinue: () -> Void

    private static let weekRange = 3...12

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            title: "Scheduled or flexible?",
            onContinue: onContinue
        ) {
            VStack(alignment: .leading, spacing: PluriSpacing.xl) {
                VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                    OnboardingSelectRowList(
                        items: ScheduleType.allCases,
                        isSelected: { answers.scheduleType == $0 },
                        label: \.title,
                        action: { answers.scheduleType = $0 }
                    )
                    Text(answers.scheduleType.subtitle)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                }

                VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                    Text("How many weeks should your plan run?")
                        .font(PluriFont.sectionHeader)
                        .foregroundStyle(PluriColor.textPrimary)

                    Text("\(answers.planLengthWeeks) weeks")
                        .font(PluriFont.displayNumeral)
                        .foregroundStyle(PluriColor.brandOrange)

                    Slider(
                        value: Binding(
                            get: { Double(answers.planLengthWeeks) },
                            set: { answers.planLengthWeeks = Int($0.rounded()) }
                        ),
                        in: Double(Self.weekRange.lowerBound)...Double(Self.weekRange.upperBound),
                        step: 1
                    )
                    .tint(PluriColor.brandOrange)

                    HStack {
                        Text("\(Self.weekRange.lowerBound) weeks")
                        Spacer()
                        Text("\(Self.weekRange.upperBound) weeks")
                    }
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textTertiary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        Q9ScheduleView(answers: OnboardingAnswers(), progress: 10.0 / 14, onContinue: {})
    }
}
