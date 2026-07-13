import SwiftUI

/// Landing screen after Q13, ahead of `PlanEngine` (M1-16/17/18 — out of
/// scope for this milestone slice). Confirms the questionnaire is done and
/// sets expectations that plan generation is next.
struct PlanGenerationStubView: View {
    var answers: OnboardingAnswers

    private var greeting: String {
        let trimmedName = answers.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "You're all set!" : "You're all set, \(trimmedName)!"
    }

    var body: some View {
        VStack(spacing: PluriSpacing.lg) {
            Spacer()

            Circle()
                .fill(PluriColor.sunriseGradient)
                .frame(width: 220, height: 220)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                }

            VStack(spacing: PluriSpacing.sm) {
                Text(greeting)
                    .font(PluriFont.title)
                    .foregroundStyle(PluriColor.textPrimary)
                Text("Plan generation is coming next — we'll build your personalized plan from everything you just told us.")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, PluriSpacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PluriColor.bgCanvas)
    }
}

#Preview {
    NavigationStack {
        PlanGenerationStubView(answers: OnboardingAnswers())
    }
}
