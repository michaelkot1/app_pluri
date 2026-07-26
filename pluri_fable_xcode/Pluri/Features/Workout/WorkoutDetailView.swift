import SwiftData
import SwiftUI

/// Which Main tab stack owns this Detail push — View Workout stays on the
/// same stack (Home / Plan / Insights) that opened Detail (SPEC §14 #42d / #64).
enum WorkoutDetailStack: Sendable {
    case home
    case plan
    case insights
}

/// Workout Detail (M4-05/06 / SPEC §7): focus-driven title/type/color,
/// equipment rollup, exercise list with set counts, View Workout → Screen
/// (M4-07/08), Skip + Notes.
struct WorkoutDetailView: View {
    var sessionID: UUID
    var stack: WorkoutDetailStack

    @Environment(PlanStore.self) private var planStore
    @Environment(MainRouter.self) private var router
    @Environment(SupabaseAuthService.self) private var authService
    @Environment(SwiftDataWorkoutSessionRepository.self) private var sessionRepository

    @State private var viewModel: WorkoutDetailViewModel?
    @State private var showsNotesSheet = false

    var body: some View {
        Group {
            if let session {
                detailContent(for: session)
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
        .id(sessionID)
        .onAppear {
            ensureViewModel()
            viewModel?.loadNotes()
        }
        .onChange(of: sessionID) { _, _ in
            viewModel = nil
            ensureViewModel()
            viewModel?.loadNotes()
        }
        .pluriBottomSheet(isPresented: $showsNotesSheet) {
            notesSheet
        }
    }

    private var session: PlannedSession? {
        guard let plan = planStore.plan else { return nil }
        return PlanMutator.session(withID: sessionID, in: plan)
    }

    @ViewBuilder
    private func detailContent(for session: PlannedSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                headerCard(for: session)

                if !session.equipmentNeeded.isEmpty {
                    equipmentSection(for: session)
                }

                exercisesSection(for: session)

                if let errorMessage = viewModel?.errorMessage {
                    Text(errorMessage)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.statusRedSoft)
                }

                actionsSection(for: session)
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    private func headerCard(for session: PlannedSession) -> some View {
        PluriCard {
            HStack(alignment: .top, spacing: PluriSpacing.sm) {
                RoundedRectangle(cornerRadius: PluriRadius.sm)
                    .fill(WorkoutColorResolver.token(for: session).color)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                    Text(session.title)
                        .font(PluriFont.sectionHeader)
                        .foregroundStyle(PluriColor.textPrimary)
                    Text(subtitle(for: session))
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                    if let statusLabel = statusLabel(for: session.status) {
                        Text(statusLabel)
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func equipmentSection(for session: PlannedSession) -> some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text("Equipment needed")
                .font(PluriFont.overline)
                .textCase(.uppercase)
                .kerning(1)
                .foregroundStyle(PluriColor.textSecondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: PluriSpacing.sm)],
                alignment: .leading,
                spacing: PluriSpacing.sm
            ) {
                ForEach(session.equipmentNeeded, id: \.self) { item in
                    Text(item)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textPrimary)
                        .padding(.horizontal, PluriSpacing.md)
                        .frame(minHeight: 44)
                        .background(PluriColor.bgMuted, in: .capsule)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func exercisesSection(for session: PlannedSession) -> some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text("Exercises")
                .font(PluriFont.overline)
                .textCase(.uppercase)
                .kerning(1)
                .foregroundStyle(PluriColor.textSecondary)

            PluriCard {
                VStack(spacing: PluriSpacing.sm) {
                    ForEach(session.exercises) { exercise in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                                Text(exercise.name)
                                    .font(PluriFont.body)
                                    .foregroundStyle(PluriColor.textPrimary)
                                Text("\(exercise.sets) sets")
                                    .font(PluriFont.label)
                                    .foregroundStyle(PluriColor.textTertiary)
                            }
                            Spacer(minLength: PluriSpacing.md)
                            Text(exercise.setsRepsSummary)
                                .font(PluriFont.label)
                                .foregroundStyle(PluriColor.textSecondary)
                                .monospacedDigit()
                        }
                        .frame(minHeight: 44, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func actionsSection(for session: PlannedSession) -> some View {
        VStack(spacing: PluriSpacing.sm) {
            Button("View Workout") {
                openWorkoutScreen()
            }
            .buttonStyle(.pluriPrimary)

            Button("Workout Notes") {
                viewModel?.loadNotes()
                showsNotesSheet = true
            }
            .buttonStyle(.pluriSecondary)

            if session.status == .scheduled {
                Button("Skip workout") {
                    Task { await viewModel?.skip(using: planStore) }
                }
                .buttonStyle(.pluriSecondary)
                .disabled(viewModel?.isSkipping == true)
            }
        }
    }

    private var notesSheet: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.md) {
            Text("Workout Notes")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)

            Text("A quick place to jot how the session felt — you can keep editing later.")
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)

            TextEditor(text: notesBinding)
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(PluriSpacing.sm)
                .frame(minHeight: 140)
                .background(PluriColor.bgMuted, in: .rect(cornerRadius: PluriRadius.md))
                .accessibilityLabel("Workout notes")

            if let errorMessage = viewModel?.errorMessage {
                Text(errorMessage)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.statusRedSoft)
            }

            Button("Save notes") {
                viewModel?.saveNotes()
                if viewModel?.errorMessage == nil {
                    showsNotesSheet = false
                }
            }
            .buttonStyle(.pluriPrimary)
        }
        .padding(PluriSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { viewModel?.notesDraft ?? "" },
            set: { viewModel?.updateNotesDraft($0) }
        )
    }

    private func ensureViewModel() {
        guard viewModel == nil else { return }
        viewModel = WorkoutDetailViewModel(
            sessionID: sessionID,
            repository: sessionRepository,
            userIDProvider: {
                authService.appUserID.flatMap(UUID.init(uuidString:))
            }
        )
    }

    private func openWorkoutScreen() {
        switch stack {
        case .home:
            router.openWorkoutScreen(sessionID: sessionID)
        case .plan:
            router.openPlanWorkoutScreen(sessionID: sessionID)
        case .insights:
            router.openInsightsWorkoutScreen(planWorkoutID: sessionID)
        }
    }

    private func subtitle(for session: PlannedSession) -> String {
        let duration = Duration.seconds(session.durationMinutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        return "\(session.workoutType.title) · \(duration) · \(session.exercises.count) exercises"
    }

    private func statusLabel(for status: WorkoutStatus) -> String? {
        switch status {
        case .scheduled:
            nil
        case .completed:
            "Completed"
        case .skipped:
            "Skipped"
        }
    }
}

#if DEBUG
#Preview("Scheduled") {
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
    NavigationStack {
        WorkoutDetailView(sessionID: sessionID, stack: .home)
    }
    .environment(store)
    .environment(MainRouter())
    .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
    .environment(SwiftDataWorkoutSessionRepository(modelContext: container.mainContext))
    .modelContainer(container)
}
#endif
