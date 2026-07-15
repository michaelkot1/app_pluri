import SwiftUI

/// The gentle failure state shown only after silent retries are exhausted
/// (M1-18 / SPEC §3.3). Tone is reassuring, never scolding (design.md §2) —
/// it reassures the user their answers are safe and offers a single retry.
struct PlanGenerationFailedView: View {
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: PluriSpacing.lg) {
            Spacer()

            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 64))
                .foregroundStyle(PluriColor.sunriseCore)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: PluriSpacing.sm) {
                Text("Let's try that again")
                    .font(PluriFont.title)
                    .foregroundStyle(PluriColor.textPrimary)

                Text("We had trouble building your plan just now. Your answers are safe — let's give it another go.")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, PluriSpacing.lg)

            Spacer()

            Button("Try again", action: onRetry)
                .buttonStyle(.pluriPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, PluriSpacing.lg)
        .padding(.bottom, PluriSpacing.md)
        .background(PluriColor.bgCanvas)
    }
}

#Preview {
    PlanGenerationFailedView(onRetry: {})
}
