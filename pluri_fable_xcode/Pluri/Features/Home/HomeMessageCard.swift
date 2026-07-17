import SwiftUI

/// Gentle full-width message card for Home's non-ready plan states (M3-07):
/// loading, no plan, or a failed restore. Kind copy, never scolding.
struct HomeMessageCard: View {
    var title: String
    var message: String

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text(title)
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)
                Text(message)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    HomeMessageCard(
        title: "We couldn't load your plan",
        message: "Check your connection and relaunch — your plan is safe on your account."
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
