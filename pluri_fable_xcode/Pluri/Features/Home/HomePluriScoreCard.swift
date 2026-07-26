import SwiftUI

/// Live Pluri Score card (M5-06 / SPEC §5.1) — value from `ScoreEngine`,
/// no sample badge or sample disclaimer.
struct HomePluriScoreCard: View {
    var score: Int?
    var subtitle: String

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("Pluri Score")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                HStack(alignment: .firstTextBaseline, spacing: PluriSpacing.xs) {
                    PluriHeroNumeral(text: displayScore)
                    Text("/ 100")
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                }

                Text(subtitle)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var displayScore: String {
        if let score {
            score.formatted(.number)
        } else {
            "—"
        }
    }

    private var accessibilityLabel: String {
        if let score {
            "Pluri Score \(score) out of 100. \(subtitle)"
        } else {
            "Pluri Score loading. \(subtitle)"
        }
    }
}

#Preview("Live") {
    HomePluriScoreCard(
        score: 78,
        subtitle: "Consistency first, with a gentle HealthKit layer — moves slowly (±3/day)."
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}

#Preview("Loading") {
    HomePluriScoreCard(
        score: nil,
        subtitle: "Based on plan consistency for now — connect Apple Health for a second layer."
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
