import SwiftUI

/// Read-only completed session summary for Insights cards without a plan link
/// (M5-17 / SPEC §14 #64). Manual "+" logs land here — not `WorkoutDetailView`.
struct InsightsCompletedSessionDetailView: View {
    var sessionID: UUID

    @Environment(SwiftDataWorkoutSessionRepository.self) private var sessionRepository
    @Environment(PlanStore.self) private var planStore

    @State private var viewModel: InsightsCompletedSessionDetailViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PluriColor.bgCanvas)
        .navigationTitle(viewModel?.title ?? "Activity")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { ensureViewModel() }
        .onChange(of: sessionID) { _, _ in
            viewModel = nil
            ensureViewModel()
        }
    }

    @ViewBuilder
    private func content(viewModel: InsightsCompletedSessionDetailViewModel) -> some View {
        if let loadErrorMessage = viewModel.loadErrorMessage {
            MainTabPlaceholderView(
                title: "Activity",
                systemImage: "figure.mixed.cardio",
                message: loadErrorMessage
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                    PluriCard {
                        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                            Text(viewModel.title)
                                .font(PluriFont.sectionHeader)
                                .foregroundStyle(PluriColor.textPrimary)
                            Text(viewModel.subtitle)
                                .font(PluriFont.label)
                                .foregroundStyle(PluriColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: PluriSpacing.lg) {
                        metric(
                            title: "Duration",
                            value: Duration.seconds(viewModel.durationSeconds)
                                .formatted(
                                    .units(allowed: [.hours, .minutes, .seconds], width: .abbreviated)
                                )
                        )
                        if let meters = viewModel.distanceMeters {
                            metric(
                                title: "Distance",
                                value: InsightsDistanceFormatting.string(
                                    meters: meters,
                                    usesImperial: viewModel.usesImperialUnits
                                )
                            )
                        }
                    }

                    if let notes = viewModel.notes,
                       !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                            Text("Notes")
                                .font(PluriFont.overline)
                                .textCase(.uppercase)
                                .kerning(1)
                                .foregroundStyle(PluriColor.textSecondary)
                            PluriCard {
                                Text(notes)
                                    .font(PluriFont.body)
                                    .foregroundStyle(PluriColor.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    if viewModel.exercises.isEmpty {
                        Text("No set logs for this activity.")
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                            Text("Sets")
                                .font(PluriFont.overline)
                                .textCase(.uppercase)
                                .kerning(1)
                                .foregroundStyle(PluriColor.textSecondary)

                            PluriCard {
                                VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                                    ForEach(viewModel.exercises) { exercise in
                                        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                                            Text(exercise.exerciseName)
                                                .font(PluriFont.label)
                                                .bold()
                                                .foregroundStyle(PluriColor.textPrimary)
                                            ForEach(exercise.sets) { set in
                                                Text(setLine(set, usesImperial: viewModel.usesImperialUnits))
                                                    .font(PluriFont.label)
                                                    .foregroundStyle(PluriColor.textSecondary)
                                            }
                                        }
                                        .accessibilityElement(children: .combine)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.horizontal, PluriSpacing.lg)
                .padding(.vertical, PluriSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
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

    private func setLine(
        _ set: WorkoutsListEngine.SetLogInput,
        usesImperial: Bool
    ) -> String {
        var parts = ["Set \(set.setNumber.formatted(.number))"]
        if let reps = set.reps {
            parts.append("\(reps.formatted(.number)) reps")
        }
        if let weightKg = set.weightKg {
            if usesImperial {
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

    private func ensureViewModel() {
        guard viewModel == nil else { return }
        let model = InsightsCompletedSessionDetailViewModel(
            sessionID: sessionID,
            repository: sessionRepository,
            planStore: planStore
        )
        model.load()
        viewModel = model
    }
}
