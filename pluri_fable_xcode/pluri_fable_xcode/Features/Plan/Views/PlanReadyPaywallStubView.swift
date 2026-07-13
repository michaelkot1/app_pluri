import SwiftUI

/// Placeholder for the forward transition out of onboarding (M1-18). The real
/// paywall + account creation is M2 (SPEC §4); until then, tapping "Unlock my
/// plan" surfaces this gentle stub so the flow doesn't dead-end silently.
struct PlanReadyPaywallStubView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: PluriSpacing.lg) {
            Spacer()

            Image(systemName: "lock.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(PluriColor.brandOrange)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: PluriSpacing.sm) {
                Text("Paywall coming soon")
                    .font(PluriFont.title)
                    .foregroundStyle(PluriColor.textPrimary)
                Text("This is where the subscription and account setup will live (M2). Your plan is generated and waiting.")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, PluriSpacing.lg)

            Spacer()

            Button("Back to my plan", action: { dismiss() })
                .buttonStyle(.pluriSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, PluriSpacing.lg)
        .padding(.bottom, PluriSpacing.md)
        .background(PluriColor.bgCanvas)
        .presentationDetents([.medium])
    }
}

#Preview {
    PlanReadyPaywallStubView()
}
