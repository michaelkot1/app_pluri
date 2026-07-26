import Charts
import SwiftData
import SwiftUI

/// Performance tab content (M5-08/09/10): week filter + per-exercise stats,
/// All-Time strength totals, and HealthKit-backed insights with kind guidance
/// (SPEC §9.1 / §14 #61).
struct InsightsPerformanceView: View {
    @Bindable var viewModel: InsightsPerformanceViewModel
    var healthSection: InsightsSection
    var onSelectHealthSection: (InsightsSection) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                InsightsWeekFilterBar(viewModel: viewModel)

                InsightsAllTimeStatsSection(viewModel: viewModel)

                InsightsHealthSection(
                    viewModel: viewModel,
                    selected: healthSection,
                    onSelect: onSelectHealthSection
                )

                if let loadErrorMessage = viewModel.loadErrorMessage {
                    InsightsEmptyCard(
                        title: "Performance",
                        message: loadErrorMessage
                    )
                } else if viewModel.isWeekEmpty {
                    InsightsEmptyCard(
                        title: "No workouts this week",
                        message: "Complete a workout and your per-exercise stats will show up here."
                    )
                } else {
                    ForEach(viewModel.exerciseStats) { stats in
                        InsightsExerciseStatsCard(stats: stats)
                    }
                }
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Week filter

private struct InsightsWeekFilterBar: View {
    @Bindable var viewModel: InsightsPerformanceViewModel

    var body: some View {
        HStack(spacing: PluriSpacing.sm) {
            Button("Previous week", systemImage: "chevron.left") {
                viewModel.goToPreviousWeek()
            }
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)

            Spacer(minLength: 0)

            Text(viewModel.weekLabel)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)

            Button("Next week", systemImage: "chevron.right") {
                viewModel.goToNextWeek()
            }
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)
        }
        .foregroundStyle(PluriColor.brandOrange)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Week filter, \(viewModel.weekLabel)")
    }
}

// MARK: - All-Time Stats (M5-09)

private struct InsightsAllTimeStatsSection: View {
    @Bindable var viewModel: InsightsPerformanceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text("All-Time")
                .font(PluriFont.overline)
                .foregroundStyle(PluriColor.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            if viewModel.isAllTimeEmpty {
                InsightsEmptyCard(
                    title: "No workouts yet",
                    message: "Complete a workout and your all-time totals will show up here."
                )
            } else {
                PluriCard {
                    VStack(alignment: .leading, spacing: PluriSpacing.md) {
                        Text(viewModel.allTimeStats.workoutCount.formatted(.number))
                            .font(PluriFont.displayNumeral)
                            .foregroundStyle(PluriColor.textPrimary)
                            .accessibilityLabel(
                                "\(viewModel.allTimeStats.workoutCount.formatted(.number)) workouts"
                            )

                        Text("Workouts")
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textSecondary)

                        HStack(spacing: PluriSpacing.lg) {
                            InsightsMetricLabel(
                                title: "Volume",
                                value: volumeText
                            )
                            InsightsMetricLabel(
                                title: "Sets",
                                value: viewModel.allTimeStats.totalSets.formatted(.number)
                            )
                            InsightsMetricLabel(
                                title: "Reps",
                                value: viewModel.allTimeStats.totalReps.formatted(.number)
                            )
                        }

                        InsightsMetricLabel(
                            title: "Total time",
                            value: durationText
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var volumeText: String {
        if let volumeKg = viewModel.allTimeStats.totalVolumeKg {
            "\(volumeKg.formatted(.number.precision(.fractionLength(0)))) kg"
        } else {
            "—"
        }
    }

    private var durationText: String {
        let total = max(0, viewModel.allTimeStats.totalDurationSeconds)
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        if hours > 0 {
            return "\(hours.formatted(.number)) hr \(minutes.formatted(.number)) min"
        }
        return "\(minutes.formatted(.number)) min"
    }
}

// MARK: - Health insights (M5-10)

private struct InsightsHealthSection: View {
    @Bindable var viewModel: InsightsPerformanceViewModel
    var selected: InsightsSection
    var onSelect: (InsightsSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text("Health")
                .font(PluriFont.overline)
                .foregroundStyle(PluriColor.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            ScrollView(.horizontal) {
                HStack(spacing: PluriSpacing.sm) {
                    ForEach(InsightsSection.allCases) { section in
                        PluriChip(
                            title: LocalizedStringKey(section.title),
                            isSelected: section == selected
                        ) {
                            onSelect(section)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)

            if let healthLoadErrorMessage = viewModel.healthLoadErrorMessage {
                InsightsEmptyCard(title: "Health", message: healthLoadErrorMessage)
            } else if viewModel.healthAuthorizationStatus != .authorized {
                InsightsEmptyCard(
                    title: selected.title,
                    message: viewModel.healthEmptyCopy
                )
            } else {
                let insights = viewModel.visibleHealthInsights(for: selected)
                if insights.allSatisfy({ $0.recentAverage == nil }) {
                    InsightsEmptyCard(
                        title: selected.title,
                        message: viewModel.healthEmptyCopy
                    )
                } else {
                    ForEach(insights) { insight in
                        InsightsHealthMetricCard(insight: insight, emptyCopy: viewModel.healthEmptyCopy)
                    }
                }
            }
        }
    }
}

private struct InsightsHealthMetricCard: View {
    var insight: HealthInsightsEngine.MetricInsight
    var emptyCopy: String

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Label {
                        Text(title)
                            .font(PluriFont.sectionHeader)
                            .foregroundStyle(PluriColor.textPrimary)
                    } icon: {
                        Image(systemName: systemImage)
                            .foregroundStyle(PluriColor.brandOrange)
                    }
                    Spacer(minLength: PluriSpacing.sm)
                    InsightsHealthTrendBadge(trend: insight.trend)
                }

                Text(averageText)
                    .font(PluriFont.displayNumeral)
                    .foregroundStyle(PluriColor.textPrimary)

                Text("7-day average")
                    .font(PluriFont.overline)
                    .foregroundStyle(PluriColor.textTertiary)
                    .textCase(.uppercase)
                    .kerning(1)

                if let baselineText {
                    Text(baselineText)
                        .font(PluriFont.body)
                        .foregroundStyle(PluriColor.textSecondary)
                }

                if let guidance = insight.guidance {
                    Text(guidance)
                        .font(PluriFont.body)
                        .foregroundStyle(PluriColor.textSecondary)
                } else if insight.recentAverage == nil {
                    Text(emptyCopy)
                        .font(PluriFont.body)
                        .foregroundStyle(PluriColor.textSecondary)
                } else {
                    Text("Keep moving — a trend appears once we have a few weeks of your own data.")
                        .font(PluriFont.body)
                        .foregroundStyle(PluriColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var title: String {
        switch insight.metric {
        case .steps: "Steps"
        case .sleep: "Sleep"
        case .calories: "Calories"
        case .activeHeartRate: "Active Heart Rate"
        }
    }

    private var systemImage: String {
        switch insight.metric {
        case .steps: "figure.walk"
        case .sleep: "bed.double.fill"
        case .calories: "flame.fill"
        case .activeHeartRate: "heart.fill"
        }
    }

    private var averageText: String {
        guard let recentAverage = insight.recentAverage else { return emptyCopy }
        switch insight.metric {
        case .steps:
            return Int(recentAverage.rounded()).formatted(.number)
        case .sleep:
            let hours = recentAverage.formatted(.number.precision(.fractionLength(1)))
            return "\(hours) hr"
        case .calories:
            let kcal = Int(recentAverage.rounded()).formatted(.number)
            return "\(kcal) kcal"
        case .activeHeartRate:
            let bpm = Int(recentAverage.rounded()).formatted(.number)
            return "\(bpm) BPM"
        }
    }

    private var baselineText: String? {
        guard let baselineAverage = insight.baselineAverage else { return nil }
        switch insight.metric {
        case .steps:
            let value = Int(baselineAverage.rounded()).formatted(.number)
            return "Your usual: \(value) steps"
        case .sleep:
            let hours = baselineAverage.formatted(.number.precision(.fractionLength(1)))
            return "Your usual: \(hours) hr"
        case .calories:
            let kcal = Int(baselineAverage.rounded()).formatted(.number)
            return "Your usual: \(kcal) kcal"
        case .activeHeartRate:
            let bpm = Int(baselineAverage.rounded()).formatted(.number)
            return "Your usual: \(bpm) BPM"
        }
    }

    private var accessibilityLabel: String {
        var parts = [title, averageText]
        if let guidance = insight.guidance {
            parts.append(guidance)
        }
        return parts.joined(separator: ", ")
    }
}

private struct InsightsHealthTrendBadge: View {
    var trend: HealthInsightsEngine.Trend

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(PluriFont.label)
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
            .accessibilityHidden(true)
    }

    private var title: String {
        switch trend {
        case .up: "Up"
        case .down: "Gentler"
        case .flat: "Steady"
        case .insufficientData: "—"
        }
    }

    private var systemImage: String {
        switch trend {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: "arrow.right"
        case .insufficientData: "minus"
        }
    }

    /// Kind tone — no scolding red for a softer recent window (SPEC §14 #61).
    private var color: Color {
        switch trend {
        case .up: PluriColor.statusGreen
        case .down, .flat, .insufficientData: PluriColor.textSecondary
        }
    }
}

// MARK: - Exercise card

private struct InsightsExerciseStatsCard: View {
    var stats: PerformanceStatsEngine.ExerciseStats

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(stats.exerciseName)
                        .font(PluriFont.sectionHeader)
                        .foregroundStyle(PluriColor.textPrimary)
                    Spacer(minLength: PluriSpacing.sm)
                    InsightsTrendBadge(trend: stats.trend)
                }

                HStack(spacing: PluriSpacing.lg) {
                    InsightsMetricLabel(
                        title: "Sets",
                        value: stats.setCount.formatted(.number)
                    )
                    InsightsMetricLabel(
                        title: "Reps",
                        value: stats.totalReps.formatted(.number)
                    )
                    InsightsMetricLabel(
                        title: "Volume",
                        value: volumeText
                    )
                }

                if stats.points.count >= 2 {
                    Chart(stats.points) { point in
                        LineMark(
                            x: .value("Day", point.dayStart, unit: .day),
                            y: .value("Reps", point.totalReps)
                        )
                        .foregroundStyle(PluriColor.brandOrange)
                        .interpolationMethod(.linear)

                        PointMark(
                            x: .value("Day", point.dayStart, unit: .day),
                            y: .value("Reps", point.totalReps)
                        )
                        .foregroundStyle(PluriColor.brandOrange)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 120)
                    .accessibilityLabel("Reps over the week for \(stats.exerciseName)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var volumeText: String {
        if let volumeKg = stats.volumeKg {
            "\(volumeKg.formatted(.number.precision(.fractionLength(0)))) kg"
        } else {
            "—"
        }
    }

    private var accessibilityLabel: String {
        var parts = [
            stats.exerciseName,
            "\(stats.setCount.formatted(.number)) sets",
            "\(stats.totalReps.formatted(.number)) reps",
        ]
        if let volumeKg = stats.volumeKg {
            parts.append(
                "volume \(volumeKg.formatted(.number.precision(.fractionLength(0)))) kilograms"
            )
        }
        parts.append(trendAccessibility)
        return parts.joined(separator: ", ")
    }

    private var trendAccessibility: String {
        switch stats.trend {
        case .up: "trending up"
        case .down: "trending down"
        case .flat: "holding steady"
        case .insufficientData: "not enough data for a trend"
        }
    }
}

private struct InsightsMetricLabel: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
            Text(title)
                .font(PluriFont.overline)
                .foregroundStyle(PluriColor.textTertiary)
                .textCase(.uppercase)
                .kerning(1)
            Text(value)
                .font(PluriFont.metricValue)
                .foregroundStyle(PluriColor.textPrimary)
        }
    }
}

private struct InsightsTrendBadge: View {
    var trend: PerformanceStatsEngine.Trend

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(PluriFont.label)
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
            .accessibilityHidden(true)
    }

    private var title: String {
        switch trend {
        case .up: "Up"
        case .down: "Down"
        case .flat: "Steady"
        case .insufficientData: "—"
        }
    }

    private var systemImage: String {
        switch trend {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: "arrow.right"
        case .insufficientData: "minus"
        }
    }

    private var color: Color {
        switch trend {
        case .up: PluriColor.statusGreen
        case .down: PluriColor.statusRedSoft
        case .flat, .insufficientData: PluriColor.textSecondary
        }
    }
}

private struct InsightsEmptyCard: View {
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

#if DEBUG
@MainActor
private enum InsightsPerformancePreviewData {
    static func viewModel(
        healthStatus: HealthKitReadAuthorizationStatus,
        populateStats: Bool
    ) -> InsightsPerformanceViewModel {
        let container = try! ModelContainer(
            for: Schema([
                WorkoutSessionRecord.self,
                SetLogRecord.self,
            ]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let healthKit = MockHealthKitReading(authorizationStatus: healthStatus)
        let viewModel = InsightsPerformanceViewModel(
            repository: SwiftDataWorkoutSessionRepository(modelContext: container.mainContext),
            healthKit: healthKit
        )
        viewModel.healthAuthorizationStatus = healthStatus

        if populateStats {
            viewModel.allTimeStats = AllTimeStatsEngine.Stats(
                workoutCount: 12,
                totalSets: 96,
                totalReps: 720,
                totalVolumeKg: 48_000,
                totalDurationSeconds: 36_000
            )
            viewModel.exerciseStats = [
                PerformanceStatsEngine.ExerciseStats(
                    exerciseName: "Back Squat",
                    setCount: 8,
                    totalReps: 64,
                    volumeKg: 5_120,
                    points: [
                        PerformanceStatsEngine.ExerciseDayPoint(
                            dayStart: .now.addingTimeInterval(-172_800),
                            setCount: 4,
                            totalReps: 32,
                            volumeKg: 2_560
                        ),
                        PerformanceStatsEngine.ExerciseDayPoint(
                            dayStart: .now.addingTimeInterval(-86_400),
                            setCount: 4,
                            totalReps: 32,
                            volumeKg: 2_560
                        ),
                    ],
                    trend: .flat
                ),
            ]
            if healthStatus == .authorized {
                viewModel.healthInsights = [
                    HealthInsightsEngine.MetricInsight(
                        metric: .steps,
                        recentAverage: 8_432,
                        baselineAverage: 8_000,
                        trend: .up,
                        guidance: "You’re ahead of your usual pace."
                    ),
                ]
            }
        }
        return viewModel
    }
}

#Preview("Empty week") {
    InsightsPerformanceView(
        viewModel: InsightsPerformancePreviewData.viewModel(
            healthStatus: .authorized,
            populateStats: false
        ),
        healthSection: .general,
        onSelectHealthSection: { _ in }
    )
    .background(PluriColor.bgCanvas)
}

#Preview("Populated") {
    InsightsPerformanceView(
        viewModel: InsightsPerformancePreviewData.viewModel(
            healthStatus: .authorized,
            populateStats: true
        ),
        healthSection: .steps,
        onSelectHealthSection: { _ in }
    )
    .background(PluriColor.bgCanvas)
}

#Preview("Health denied") {
    InsightsPerformanceView(
        viewModel: InsightsPerformancePreviewData.viewModel(
            healthStatus: .denied,
            populateStats: true
        ),
        healthSection: .steps,
        onSelectHealthSection: { _ in }
    )
    .background(PluriColor.bgCanvas)
}
#endif
