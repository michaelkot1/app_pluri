import SwiftUI

/// Temporary post-paywall confirmation until account creation (M2-11) ships.
struct PaywallUnlockedPlaceholderView: View {
    var body: some View {
        VStack(spacing: PluriSpacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(PluriColor.brandOrange)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: PluriSpacing.sm) {
                Text("You're in")
                    .font(PluriFont.title)
                    .foregroundStyle(PluriColor.textPrimary)

                Text("Account creation is next (M2-11). Your plan is unlocked and waiting.")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, PluriSpacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PluriColor.bgCanvas)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NavigationStack {
        PaywallUnlockedPlaceholderView()
    }
}
