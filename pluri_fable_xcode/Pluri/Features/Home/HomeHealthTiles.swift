import SwiftUI

/// Prominent Health cards using today's real values, optional personal goals,
/// and the user's own baseline when a goal has not been set.
struct HomeHealthMetricsGrid: View {
    var metrics: [HomeHealthMetricPresentation]
    var onOpen: (InsightsSection) -> Void
    var onEditGoal: (HomeHealthMetricPresentation) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: PluriSpacing.sm),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.md) {
            VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                Text("Today's Health")
                    .font(PluriFont.title)
                    .foregroundStyle(PluriColor.textPrimary)
                Text("Your goals and your own history — never generic targets.")
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: PluriSpacing.sm) {
                ForEach(metrics) { metric in
                    HomeHealthMetricCard(
                        metric: metric,
                        onOpen: onOpen,
                        onEditGoal: onEditGoal
                    )
                }
            }
        }
    }
}

private struct HomeHealthMetricCard: View {
    var metric: HomeHealthMetricPresentation
    var onOpen: (InsightsSection) -> Void
    var onEditGoal: (HomeHealthMetricPresentation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Button {
                onOpen(metric.kind.insightsSection)
            } label: {
                VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                    Image(systemName: metric.kind.systemImage)
                        .font(PluriFont.metricValue)
                        .foregroundStyle(metric.kind.accent)
                        .frame(width: 44, height: 44)
                        .background(metric.kind.accent.opacity(0.14), in: .circle)

                    Text(metric.kind.title)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)

                    Text(metric.value)
                        .font(PluriFont.metricValue)
                        .foregroundStyle(PluriColor.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(metric.detail)
                        .font(PluriFont.overline)
                        .foregroundStyle(PluriColor.textSecondary)
                        .lineLimit(2, reservesSpace: true)

                    if let progress = metric.progress {
                        ProgressView(value: progress)
                            .tint(metric.kind.accent)
                            .accessibilityLabel("\(metric.kind.title) goal progress")
                            .accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0))))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(metric.kind.title), \(metric.value), \(metric.detail)")
            .accessibilityHint("Opens \(metric.kind.title) in Insights")

            if metric.kind.goalKind != nil {
                Button(metric.goal == nil ? "Set goal" : "Edit goal") {
                    onEditGoal(metric)
                }
                .font(PluriFont.label)
                .foregroundStyle(metric.kind.accent)
                .frame(minHeight: 44)
            }
        }
        .padding(PluriSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(PluriColor.bgSurface, in: .rect(cornerRadius: PluriRadius.lg))
        .pluriShadow(.card)
    }
}

extension HomeHealthMetricPresentation.Kind {
    var title: String {
        switch self {
        case .steps: "Steps"
        case .sleep: "Sleep"
        case .activeEnergy: "Active Energy"
        case .averageHeartRate: "Average Heart Rate"
        }
    }

    var systemImage: String {
        switch self {
        case .steps: "figure.walk"
        case .sleep: "moon.stars.fill"
        case .activeEnergy: "flame.fill"
        case .averageHeartRate: "heart.fill"
        }
    }

    var insightsSection: InsightsSection {
        switch self {
        case .steps: .steps
        case .sleep: .sleep
        case .activeEnergy: .calories
        case .averageHeartRate: .activeHeartRate
        }
    }

    var accent: Color {
        switch self {
        case .steps: PluriColor.brandOrange
        case .sleep: PluriColor.statusBlue
        case .activeEnergy: PluriColor.sunriseCore
        case .averageHeartRate: PluriColor.accentPink
        }
    }

    var unitLabel: String {
        switch self {
        case .steps: "steps"
        case .sleep: "hours"
        case .activeEnergy: "kcal"
        case .averageHeartRate: "BPM"
        }
    }
}
