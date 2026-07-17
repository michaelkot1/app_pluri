import SwiftUI

/// Gentle placeholder body for Main tabs whose real content ships in M3+.
struct MainTabPlaceholderView: View {
    var title: String
    var systemImage: String
    var message: String

    var body: some View {
        VStack(spacing: PluriSpacing.lg) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(PluriColor.brandOrange)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: PluriSpacing.sm) {
                Text(title)
                    .font(PluriFont.title)
                    .foregroundStyle(PluriColor.textPrimary)

                Text(message)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, PluriSpacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PluriColor.bgCanvas)
        .navigationTitle(title)
    }
}

#Preview {
    NavigationStack {
        MainTabPlaceholderView(
            title: "Plan",
            systemImage: "calendar",
            message: "Your full plan, week cards, and calendar arrive in the next update."
        )
    }
}
