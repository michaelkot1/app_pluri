import SwiftUI

/// The Home focal metric: a live score ring over one restrained sunrise glow.
struct HomePluriScoreHero: View {
    var presentation: HomePluriScorePresentation

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                Text("Pluri Score")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                HomeScoreComposition(presentation: presentation)

                Text(presentation.subtitle)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if let score = presentation.score {
            "Pluri Score \(score) out of 100. \(presentation.consistency). \(presentation.health). \(presentation.subtitle)"
        } else {
            "Pluri Score updating. \(presentation.subtitle)"
        }
    }
}

private struct HomeScoreComposition: View {
    var presentation: HomePluriScorePresentation

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PluriSpacing.lg) {
                HomeScoreRing(score: presentation.score)
                HomeScoreComponents(presentation: presentation)
            }

            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                HomeScoreRing(score: presentation.score)
                    .frame(maxWidth: .infinity)
                HomeScoreComponents(presentation: presentation)
            }
        }
    }
}

private struct HomeScoreComponents: View {
    var presentation: HomePluriScorePresentation

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Label(presentation.consistency, systemImage: "checkmark.circle")
            Label(presentation.health, systemImage: "heart.text.square")
        }
        .font(PluriFont.label)
        .foregroundStyle(PluriColor.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeScoreRing: View {
    var score: Int?

    @ScaledMetric(relativeTo: .largeTitle) private var ringSize = 142

    private var progress: Double {
        Double(score ?? 0) / 100
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(PluriColor.sunriseGradient)
                .blur(radius: 12)
                .opacity(0.72)

            Circle()
                .stroke(PluriColor.lineDivider, lineWidth: 12)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [
                            PluriColor.brandOrange,
                            PluriColor.sunriseCore,
                            PluriColor.brandCoralSoft,
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(score?.formatted(.number) ?? "—")
                    .font(PluriFont.displayNumeral)
                    .monospacedDigit()
                    .foregroundStyle(PluriColor.textPrimary)
                Text("/ 100")
                    .font(PluriFont.overline)
                    .foregroundStyle(PluriColor.textSecondary)
            }
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityHidden(true)
    }
}

#Preview("Live") {
    HomePluriScoreHero(
        presentation: HomePluriScorePresentation(
            result: ScoreEngine.Result(
                score: 78,
                consistencyComponent: 82,
                healthComponent: 69,
                usedHealthComponent: true,
                rawUnclamped: 78
            )
        )
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
