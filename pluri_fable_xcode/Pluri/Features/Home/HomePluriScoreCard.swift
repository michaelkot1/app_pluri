import SwiftUI

/// Pluri Score card (M3-08 / SPEC §5.1) showing a clearly-identified sample
/// score — the real engine lands in M5, so the card never pretends the value
/// is live.
struct HomePluriScoreCard: View {
    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                HStack {
                    Text("Pluri Score")
                        .font(PluriFont.sectionHeader)
                        .foregroundStyle(PluriColor.textPrimary)
                    Spacer(minLength: PluriSpacing.sm)
                    Text(HomeViewModel.stubScoreBadge)
                        .font(PluriFont.overline)
                        .textCase(.uppercase)
                        .kerning(1)
                        .foregroundStyle(PluriColor.textSecondary)
                        .padding(.horizontal, PluriSpacing.sm)
                        .padding(.vertical, PluriSpacing.xs)
                        .background(PluriColor.bgMuted, in: .capsule)
                }

                HStack(alignment: .firstTextBaseline, spacing: PluriSpacing.xs) {
                    PluriHeroNumeral(text: HomeViewModel.stubScoreValue.formatted(.number))
                    Text("/ 100")
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                }

                Text(HomeViewModel.stubScoreDisclaimer)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomePluriScoreCard()
        .padding(PluriSpacing.lg)
        .background(PluriColor.bgCanvas)
}
