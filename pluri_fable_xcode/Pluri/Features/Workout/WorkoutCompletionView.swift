import SwiftData
import SwiftUI

/// Workout completion summary (M4-12/13/14/19 / SPEC §8.1): totals, per-exercise
/// results, notes, optional Apple Health sync, Discard / Save → Done.
struct WorkoutCompletionView: View {
    var planWorkoutID: UUID
    var workoutSessionID: UUID
    var elapsedSeconds: Int
    var stack: WorkoutDetailStack

    @Environment(PlanStore.self) private var planStore
    @Environment(MainRouter.self) private var router
    @Environment(SwiftDataWorkoutSessionRepository.self) private var sessionRepository

    @State private var viewModel: WorkoutCompletionViewModel?

    var body: some View {
        Group {
            if let viewModel {
                completionContent(viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PluriColor.bgCanvas)
        .navigationTitle("Workout complete")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel?.didSaveLocally == true)
        .id("\(planWorkoutID.uuidString)-\(workoutSessionID.uuidString)")
        .onAppear {
            ensureViewModel()
            viewModel?.load(using: planStore)
        }
        .onChange(of: planWorkoutID) { _, _ in
            recreateViewModel()
        }
        .onChange(of: workoutSessionID) { _, _ in
            recreateViewModel()
        }
        .onChange(of: viewModel?.didFinish) { _, didFinish in
            guard didFinish == true else { return }
            finishNavigation()
        }
    }

    @ViewBuilder
    private func completionContent(_ viewModel: WorkoutCompletionViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                summarySection(viewModel)

                resultsSection(viewModel)

                notesSection(viewModel)

                if !viewModel.didSaveLocally {
                    Toggle("Sync to Apple Health", isOn: Binding(
                        get: { viewModel.syncToAppleHealth },
                        set: { viewModel.syncToAppleHealth = $0 }
                    ))
                    .tint(PluriColor.brandOrange)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textPrimary)
                    .accessibilityHint("When on, Pluri writes this workout to Apple Health after you save.")
                }

                if let healthSyncMessage = viewModel.healthSyncMessage {
                    Text(healthSyncMessage)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                        .accessibilityLabel(healthSyncMessage)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.statusRedSoft)
                }

                actionsSection(viewModel)
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    private func summarySection(_ viewModel: WorkoutCompletionViewModel) -> some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text(viewModel.workoutName)
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                labeledRow(title: "Date", value: viewModel.datePerformedLabel)
                labeledRow(title: "Planned", value: viewModel.plannedDurationLabel)
                labeledRow(title: "Actual", value: viewModel.actualDurationLabel)
                labeledRow(
                    title: "Total reps",
                    value: viewModel.totalReps.formatted(.number)
                )
            }
        }
    }

    private func labeledRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
            Spacer(minLength: PluriSpacing.sm)
            Text(value)
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textPrimary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func resultsSection(_ viewModel: WorkoutCompletionViewModel) -> some View {
        if viewModel.exerciseResults.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text("Results")
                    .font(PluriFont.overline)
                    .textCase(.uppercase)
                    .kerning(1)
                    .foregroundStyle(PluriColor.textSecondary)

                PluriCard {
                    VStack(alignment: .leading, spacing: PluriSpacing.md) {
                        ForEach(viewModel.exerciseResults) { exercise in
                            VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                                Text(exercise.exerciseName)
                                    .font(PluriFont.label)
                                    .bold()
                                    .foregroundStyle(PluriColor.textPrimary)
                                ForEach(exercise.sets) { set in
                                    Text(viewModel.setLine(for: set))
                                        .font(PluriFont.label)
                                        .foregroundStyle(PluriColor.textSecondary)
                                        .monospacedDigit()
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }

    private func notesSection(_ viewModel: WorkoutCompletionViewModel) -> some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text("Notes")
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)

            TextField(
                "How did it feel?",
                text: Binding(
                    get: { viewModel.notesDraft },
                    set: { viewModel.updateNotesDraft($0) }
                ),
                axis: .vertical
            )
            .lineLimit(3...6)
            .font(PluriFont.body)
            .foregroundStyle(PluriColor.textPrimary)
            .padding(PluriSpacing.md)
            .background(PluriColor.bgMuted, in: .rect(cornerRadius: PluriRadius.md))
            .disabled(viewModel.didSaveLocally)
            .accessibilityLabel("Workout notes")
        }
    }

    @ViewBuilder
    private func actionsSection(_ viewModel: WorkoutCompletionViewModel) -> some View {
        if viewModel.didSaveLocally {
            Button("Done") {
                viewModel.acknowledgeHealthMessageAndFinish()
            }
            .buttonStyle(.pluriPrimary)
            .disabled(viewModel.isSaving || viewModel.isDiscarding)
        } else {
            Button("Save") {
                Task { await viewModel.save(using: planStore) }
            }
            .buttonStyle(.pluriPrimary)
            .disabled(viewModel.isSaving || viewModel.isDiscarding)

            Button("Discard") {
                Task { await viewModel.discard() }
            }
            .buttonStyle(.pluriSecondary)
            .disabled(viewModel.isSaving || viewModel.isDiscarding)
        }
    }

    private func ensureViewModel() {
        guard viewModel == nil else { return }
        viewModel = WorkoutCompletionViewModel(
            planWorkoutID: planWorkoutID,
            workoutSessionID: workoutSessionID,
            elapsedSecondsHint: elapsedSeconds,
            repository: sessionRepository,
            healthWriter: LiveWorkoutHealthWriter()
        )
    }

    private func recreateViewModel() {
        viewModel = nil
        ensureViewModel()
        viewModel?.load(using: planStore)
    }

    /// Pop Screen + Completion so the user lands on Detail (SPEC §14 #56).
    private func finishNavigation() {
        switch stack {
        case .home:
            router.finishHomeWorkoutCompletion()
        case .plan:
            router.finishPlanWorkoutCompletion()
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        WorkoutCompletionView(
            planWorkoutID: UUID(),
            workoutSessionID: UUID(),
            elapsedSeconds: 1_245,
            stack: .home
        )
    }
    .environment(HomePreviewData.readyStore())
    .environment(MainRouter())
    .environment(
        SwiftDataWorkoutSessionRepository(
            modelContext: try! ModelContainer(
                for: Schema([WorkoutSessionRecord.self, SetLogRecord.self]),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ).mainContext
        )
    )
}
#endif
