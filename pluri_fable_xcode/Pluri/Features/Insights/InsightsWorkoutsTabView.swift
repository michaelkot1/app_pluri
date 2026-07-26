import SwiftData
import SwiftUI

/// Workouts tab: completed sessions grouped by month (M5-11 / SPEC §9.2).
struct InsightsWorkoutsTabView: View {
    @Bindable var viewModel: InsightsWorkoutsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                if viewModel.hasDayFilter, let label = viewModel.dayFilterLabel {
                    InsightsDayFilterBanner(
                        dayLabel: label,
                        onClear: { viewModel.clearDayFilter() }
                    )
                }

                if let loadErrorMessage = viewModel.loadErrorMessage {
                    InsightsWorkoutsEmptyCard(
                        title: "Workouts",
                        message: loadErrorMessage
                    )
                } else if viewModel.isEmpty {
                    InsightsWorkoutsEmptyCard(
                        title: viewModel.hasDayFilter ? "No workouts this day" : "No workouts yet",
                        message: viewModel.hasDayFilter
                            ? "Nothing logged on this day. Clear the day filter to see all workouts."
                            : "Complete a plan workout or tap + to log an activity."
                    )
                } else {
                    ForEach(viewModel.monthGroups) { group in
                        InsightsMonthGroupSection(
                            group: group,
                            usesImperialUnits: viewModel.usesImperialUnits
                        )
                    }
                }
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Day filter banner

private struct InsightsDayFilterBanner: View {
    var dayLabel: String
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: PluriSpacing.sm) {
            Text("Showing \(dayLabel)")
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
            Spacer(minLength: 0)
            Button("Clear") {
                onClear()
            }
            .font(PluriFont.label)
            .foregroundStyle(PluriColor.brandOrange)
            .frame(minHeight: 44)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Day filter, \(dayLabel)")
        .accessibilityHint("Clear to show all workouts")
    }
}

// MARK: - Month group

private struct InsightsMonthGroupSection: View {
    var group: WorkoutsListEngine.MonthGroup
    var usesImperialUnits: Bool

    @Environment(MainRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(monthTitle)
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)
                Spacer(minLength: 0)
                Text(totalsText)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ForEach(group.workouts) { workout in
                InsightsWorkoutSessionCard(
                    workout: workout,
                    usesImperialUnits: usesImperialUnits,
                    onOpenDetail: { openDetail(for: workout) }
                )
            }
        }
    }

    private func openDetail(for workout: WorkoutsListEngine.WorkoutCard) {
        if let planWorkoutId = workout.planWorkoutId {
            router.openInsightsWorkoutDetail(planWorkoutID: planWorkoutId)
        } else {
            router.openInsightsCompletedSession(sessionID: workout.id)
        }
    }

    private var monthTitle: String {
        group.monthStart.formatted(.dateTime.month(.wide).year())
    }

    private var totalsText: String {
        let count = group.workoutCount
        let countText = "\(count.formatted(.number)) \(count == 1 ? "workout" : "workouts")"
        if let meters = group.totalDistanceMeters {
            return "\(countText) · \(formattedDistance(meters))"
        }
        return countText
    }

    private func formattedDistance(_ meters: Double) -> String {
        InsightsDistanceFormatting.string(meters: meters, usesImperial: usesImperialUnits)
    }
}

// MARK: - Expandable session card

private struct InsightsWorkoutSessionCard: View {
    var workout: WorkoutsListEngine.WorkoutCard
    var usesImperialUnits: Bool
    var onOpenDetail: () -> Void

    @State private var isExpanded = false

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                HStack(alignment: .top, spacing: PluriSpacing.sm) {
                    Button(action: onOpenDetail) {
                        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                            Text(workout.description)
                                .font(PluriFont.sectionHeader)
                                .foregroundStyle(PluriColor.textPrimary)
                                .multilineTextAlignment(.leading)

                            Text(subtitle)
                                .font(PluriFont.label)
                                .foregroundStyle(PluriColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(workout.description)
                    .accessibilityHint(
                        workout.planWorkoutId == nil
                            ? "Opens completed activity details"
                            : "Opens workout details"
                    )

                    Button {
                        isExpanded.toggle()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(PluriColor.textTertiary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "Collapse sets" : "Expand sets")
                    .accessibilityHint("Shows duration, reps, and logged sets")
                }

                if isExpanded {
                    expandedDetail
                }
            }
        }
    }

    private var subtitle: String {
        var parts = [
            workout.startedAt.formatted(date: .abbreviated, time: .omitted),
            durationText,
        ]
        if workout.totalReps > 0 {
            parts.append("\(workout.totalReps.formatted(.number)) reps")
        }
        if let meters = workout.distanceMeters {
            parts.append(InsightsDistanceFormatting.string(meters: meters, usesImperial: usesImperialUnits))
        }
        return parts.joined(separator: " · ")
    }

    private var durationText: String {
        Duration.seconds(workout.durationSeconds)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
    }

    @ViewBuilder
    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            HStack(spacing: PluriSpacing.lg) {
                metric(title: "Duration", value: durationText)
                metric(
                    title: "Total reps",
                    value: workout.totalReps.formatted(.number)
                )
            }

            if let meters = workout.distanceMeters {
                metric(
                    title: "Distance",
                    value: InsightsDistanceFormatting.string(
                        meters: meters,
                        usesImperial: usesImperialUnits
                    )
                )
            }

            if workout.exercises.isEmpty {
                Text("No set logs for this activity.")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)
            } else {
                ForEach(workout.exercises) { exercise in
                    VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                        Text(exercise.exerciseName)
                            .font(PluriFont.label)
                            .bold()
                            .foregroundStyle(PluriColor.textPrimary)
                        ForEach(exercise.sets) { set in
                            Text(setLine(set))
                                .font(PluriFont.label)
                                .foregroundStyle(PluriColor.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(PluriFont.overline)
                .foregroundStyle(PluriColor.textTertiary)
                .textCase(.uppercase)
            Text(value)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textPrimary)
        }
    }

    private func setLine(_ set: WorkoutsListEngine.SetLogInput) -> String {
        var parts = ["Set \(set.setNumber.formatted(.number))"]
        if let reps = set.reps {
            parts.append("\(reps.formatted(.number)) reps")
        }
        if let weightKg = set.weightKg {
            if usesImperialUnits {
                let pounds = Measurement(value: weightKg, unit: UnitMass.kilograms)
                    .converted(to: .pounds)
                    .value
                parts.append(
                    "\(pounds.formatted(.number.precision(.fractionLength(0...1)))) lb"
                )
            } else {
                parts.append(
                    "\(weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg"
                )
            }
        }
        if let durationSeconds = set.durationSeconds, durationSeconds > 0 {
            parts.append(
                Duration.seconds(durationSeconds)
                    .formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated))
            )
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Empty

private struct InsightsWorkoutsEmptyCard: View {
    var title: String
    var message: String

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Label {
                    Text(title)
                        .font(PluriFont.sectionHeader)
                        .foregroundStyle(PluriColor.textPrimary)
                } icon: {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(PluriColor.brandOrange)
                }
                Text(message)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Distance formatting

enum InsightsDistanceFormatting {
    static func string(meters: Double, usesImperial: Bool) -> String {
        if usesImperial {
            let miles = Measurement(value: meters, unit: UnitLength.meters)
                .converted(to: .miles)
                .value
            return "\(miles.formatted(.number.precision(.fractionLength(0...2)))) mi"
        }
        let kilometers = Measurement(value: meters, unit: UnitLength.meters)
            .converted(to: .kilometers)
            .value
        return "\(kilometers.formatted(.number.precision(.fractionLength(0...2)))) km"
    }
}

#if DEBUG
@MainActor
private enum InsightsWorkoutsPreviewData {
    static func viewModel(populated: Bool) -> InsightsWorkoutsViewModel {
        let container = try! ModelContainer(
            for: Schema([
                WorkoutSessionRecord.self,
                SetLogRecord.self,
            ]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let viewModel = InsightsWorkoutsViewModel(
            repository: SwiftDataWorkoutSessionRepository(modelContext: container.mainContext),
            planStore: PlanStore(mutationService: MockPlanMutationService())
        )
        if populated {
            let day = Date(timeIntervalSince1970: 1_784_073_600)
            viewModel.monthGroups = [
                WorkoutsListEngine.MonthGroup(
                    monthStart: day,
                    workoutCount: 2,
                    totalDistanceMeters: 3_500,
                    workouts: [
                        WorkoutsListEngine.WorkoutCard(
                            id: UUID(),
                            description: "Plan Push",
                            startedAt: day,
                            durationSeconds: 2_400,
                            totalReps: 48,
                            distanceMeters: nil,
                            activityType: "workout",
                            isManualLog: false,
                            planWorkoutId: UUID(),
                            exercises: [
                                WorkoutsListEngine.ExerciseSets(
                                    exerciseName: "Bench Press",
                                    sets: [
                                        WorkoutsListEngine.SetLogInput(
                                            id: UUID(),
                                            exerciseName: "Bench Press",
                                            setNumber: 1,
                                            reps: 8,
                                            weightKg: 60,
                                            durationSeconds: nil
                                        ),
                                    ]
                                ),
                            ]
                        ),
                        WorkoutsListEngine.WorkoutCard(
                            id: UUID(),
                            description: "Easy jog",
                            startedAt: day.addingTimeInterval(3_600),
                            durationSeconds: 1_800,
                            totalReps: 0,
                            distanceMeters: 3_500,
                            activityType: "cardio",
                            isManualLog: true,
                            planWorkoutId: nil,
                            exercises: []
                        ),
                    ]
                ),
            ]
        }
        return viewModel
    }
}

#Preview("Empty") {
    InsightsWorkoutsTabView(viewModel: InsightsWorkoutsPreviewData.viewModel(populated: false))
        .background(PluriColor.bgCanvas)
        .environment(MainRouter())
}

#Preview("Populated") {
    InsightsWorkoutsTabView(viewModel: InsightsWorkoutsPreviewData.viewModel(populated: true))
        .background(PluriColor.bgCanvas)
        .environment(MainRouter())
}
#endif
