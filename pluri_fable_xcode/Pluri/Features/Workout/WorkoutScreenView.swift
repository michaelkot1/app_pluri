import SwiftData
import SwiftUI

/// Live Workout Screen (M4-07–11 / SPEC §8): idle → Start → running timer,
/// Pause/Stop (= pause, expands controls) / hold-to-finish → completion; inline Log; live HealthKit.
struct WorkoutScreenView: View {
    var sessionID: UUID
    var stack: WorkoutDetailStack = .home

    @Environment(PlanStore.self) private var planStore
    @Environment(MainRouter.self) private var router
    @Environment(SupabaseAuthService.self) private var authService
    @Environment(SwiftDataWorkoutSessionRepository.self) private var sessionRepository
    @Environment(SupabaseSyncEngine.self) private var syncEngine
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: WorkoutScreenViewModel?
    @State private var holdProgress = 0.0
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let session {
                screenContent(for: session)
            } else {
                MainTabPlaceholderView(
                    title: "Workout",
                    systemImage: "dumbbell.fill",
                    message: "We couldn't find that workout in your plan. Head back and pick another."
                )
            }
        }
        .background(PluriColor.bgCanvas)
        .navigationTitle(session?.title ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        // The screen stays mounted under a sheet; hold GIFs on their first frame
        // so the sheet isn't fighting N animations for the main thread (§14 #76).
        .environment(\.exerciseMediaAnimationEnabled, !isCoveredBySheet)
        .id(sessionID)
        .onAppear {
            ensureViewModel()
            viewModel?.refreshSessionState()
        }
        .onChange(of: sessionID) { _, _ in
            recreateViewModelForCurrentSession()
        }
        .onDisappear {
            holdTask?.cancel()
            viewModel?.tearDown()
        }
        .pluriBottomSheet(isPresented: exerciseSheetBinding) {
            if let session, let exercise = selectedExercise(in: session) {
                exerciseDetailSheet(for: exercise)
            }
        }
    }

    private var session: PlannedSession? {
        guard let plan = planStore.plan else { return nil }
        return PlanMutator.session(withID: sessionID, in: plan)
    }

    @ViewBuilder
    private func screenContent(for session: PlannedSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                if let viewModel {
                    WorkoutTimerMetricsView(viewModel: viewModel)

                    WorkoutExerciseListView(
                        session: session,
                        viewModel: viewModel,
                        usesImperialUnits: planStore.profile?.units == "imperial"
                    )
                } else {
                    WorkoutTimerMetricsPlaceholderView()
                }

                if let errorMessage = viewModel?.errorMessage {
                    Text(errorMessage)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.statusRedSoft)
                }
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.top, PluriSpacing.lg)
            // Keep the last card clear of the floating controls.
            .padding(.bottom, PluriSpacing.xxl + PluriSpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .bottom) {
            WorkoutLiveControlsBar(
                showsLiveControls: viewModel?.showsLiveControls == true,
                isPaused: viewModel?.isPaused == true,
                holdProgress: holdProgress,
                onStart: { viewModel?.start() },
                onPauseOrStop: { viewModel?.stop() },
                onResume: { viewModel?.resume() },
                onHoldChanged: { beginHoldIfNeeded() },
                onHoldEnded: { cancelHold() }
            )
        }
    }

    private func exerciseDetailSheet(for exercise: PlannedExercise) -> some View {
        let catalog = viewModel?.catalogExercise(for: exercise)
        return WorkoutExerciseDetailSheet(
            exercise: exercise,
            descriptionText: viewModel?.description(for: exercise) ?? "",
            videoURL: catalog?.videoURL,
            notesDraft: notesBinding(for: exercise.id),
            errorMessage: viewModel?.errorMessage,
            onSaveNotes: {
                viewModel?.saveExerciseNotes(for: exercise.id)
                if viewModel?.errorMessage == nil {
                    viewModel?.selectExercise(nil)
                }
            }
        )
    }

    private func notesBinding(for exerciseID: UUID) -> Binding<String> {
        Binding(
            get: { viewModel?.notesDraft(for: exerciseID) ?? "" },
            set: { viewModel?.updateExerciseNotesDraft($0, for: exerciseID) }
        )
    }

    private var isCoveredBySheet: Bool {
        guard let viewModel else { return false }
        return viewModel.selectedExerciseID != nil
    }

    private var exerciseSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.selectedExerciseID != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel?.selectExercise(nil)
                }
            }
        )
    }

    private func selectedExercise(in session: PlannedSession) -> PlannedExercise? {
        guard let id = viewModel?.selectedExerciseID else { return nil }
        return session.exercises.first { $0.id == id }
    }

    private func beginHoldIfNeeded() {
        guard holdTask == nil else { return }
        holdProgress = 0
        holdTask = Task {
            let steps = 20
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                holdProgress = Double(step) / Double(steps)
            }
            guard !Task.isCancelled else { return }
            requestCompletion()
            holdProgress = 0
            holdTask = nil
        }
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        holdProgress = 0
    }

    private func requestCompletion() {
        viewModel?.finish()
        guard let handoff = viewModel?.pendingCompletion else { return }
        navigateToCompletion(handoff)
        viewModel?.clearPendingCompletion()
    }

    private func navigateToCompletion(_ handoff: WorkoutCompletionHandoff) {
        switch stack {
        case .home:
            router.openWorkoutCompletion(
                planWorkoutID: handoff.planWorkoutID,
                workoutSessionID: handoff.workoutSessionID,
                elapsedSeconds: handoff.elapsedSeconds
            )
        case .plan:
            router.openPlanWorkoutCompletion(
                planWorkoutID: handoff.planWorkoutID,
                workoutSessionID: handoff.workoutSessionID,
                elapsedSeconds: handoff.elapsedSeconds
            )
        case .insights:
            router.openInsightsWorkoutCompletion(
                planWorkoutID: handoff.planWorkoutID,
                workoutSessionID: handoff.workoutSessionID,
                elapsedSeconds: handoff.elapsedSeconds
            )
        }
    }

    private func ensureViewModel() {
        guard viewModel == nil else { return }
        viewModel = makeViewModel()
    }

    /// NavigationStack can reuse a destination when only `sessionID` changes;
    /// tear down the old VM so timer/sets/pause never bleed across workouts.
    private func recreateViewModelForCurrentSession() {
        holdTask?.cancel()
        holdTask = nil
        holdProgress = 0
        viewModel?.tearDown()
        viewModel = nil
        ensureViewModel()
        viewModel?.refreshSessionState()
    }

    private func makeViewModel() -> WorkoutScreenViewModel {
        let context = modelContext
        let health = LiveWorkoutHealthMetricsProvider()
        return WorkoutScreenViewModel(
            sessionID: sessionID,
            repository: sessionRepository,
            userIDProvider: {
                authService.appUserID.flatMap(UUID.init(uuidString:))
            },
            catalogLookup: { exerciseID in
                var descriptor = FetchDescriptor<CachedExercise>(
                    predicate: #Predicate { cached in
                        cached.id == exerciseID
                    }
                )
                descriptor.fetchLimit = 1
                return try? context.fetch(descriptor).first?.asDomainExercise
            },
            syncEngine: syncEngine,
            healthMetrics: health,
            usesImperialUnits: {
                planStore.profile?.units == "imperial"
            }
        )
    }
}

#if DEBUG
#Preview("Pre-start") {
    WorkoutScreenPreviewFactory.make(seed: .none)
}

#Preview("Active running") {
    WorkoutScreenPreviewFactory.make(seed: .running)
}

#Preview("Active paused") {
    WorkoutScreenPreviewFactory.make(seed: .paused)
}

#Preview("Offline resume") {
    WorkoutScreenPreviewFactory.make(seed: .offlineResume)
}

@MainActor
enum WorkoutScreenPreviewFactory {
    enum Seed {
        case none
        case running
        case paused
        case offlineResume
    }

    static func make(seed: Seed) -> some View {
        let store = HomePreviewData.readyStore()
        let sessionID = store.plan?.weeks[0].sessions[1].id ?? UUID()
        let container = try! ModelContainer(
            for: Schema([
                CachedExercise.self,
                ExerciseCatalogSyncState.self,
                WorkoutSessionRecord.self,
                SetLogRecord.self,
            ]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataWorkoutSessionRepository(modelContext: container.mainContext)
        seedSession(seed, planWorkoutID: sessionID, repository: repository)

        let sync = SupabaseSyncEngine(
            modelContext: container.mainContext,
            supabaseService: SupabaseService()
        )
        return NavigationStack {
            WorkoutScreenView(sessionID: sessionID, stack: .home)
        }
        .environment(store)
        .environment(MainRouter())
        .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
        .environment(repository)
        .environment(sync)
        .modelContainer(container)
    }

    private static func seedSession(
        _ seed: Seed,
        planWorkoutID: UUID,
        repository: SwiftDataWorkoutSessionRepository
    ) {
        let userID = UUID()
        switch seed {
        case .none:
            break
        case .running:
            if let session = try? repository.startOrResume(planWorkoutId: planWorkoutID, userId: userID) {
                try? repository.resume(sessionId: session.id)
            }
        case .paused:
            if let session = try? repository.startOrResume(planWorkoutId: planWorkoutID, userId: userID) {
                try? repository.resume(sessionId: session.id)
                try? repository.pause(sessionId: session.id)
            }
        case .offlineResume:
            // In-progress paused session with elapsed — Screen refresh restores it.
            if let session = try? repository.startOrResume(planWorkoutId: planWorkoutID, userId: userID) {
                try? repository.resume(sessionId: session.id)
                try? repository.pause(sessionId: session.id)
                if let record = try? repository.session(id: session.id) {
                    record.accumulatedActiveSeconds = 540
                    record.needsSync = true
                }
            }
        }
    }
}
#endif
