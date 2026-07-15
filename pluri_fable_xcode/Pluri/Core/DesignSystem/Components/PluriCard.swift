import SwiftUI

/// A cushiony rounded surface card with the elevation-1 shadow (design.md §6).
struct PluriCard<Content: View>: View {
    var backgroundColor = PluriColor.bgSurface
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(PluriSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor, in: .rect(cornerRadius: PluriRadius.lg))
            .pluriShadow(.card)
    }
}

#Preview {
    VStack(spacing: PluriSpacing.md) {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                Text("Wellness")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)
                Text("You're on a gentle path today.")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
            }
        }
        PluriCard(backgroundColor: PluriColor.accentPink) {
            Text("Food you've burned")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(.white)
        }
    }
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
