import SwiftData
import SwiftUI

/// Which Main tab stack owns this Detail push — Start Workout stays on the
/// same stack (Home / Plan / Insights) that opened Detail.
enum WorkoutDetailStack: Sendable {
    case home
    case plan
    case insights
}

/// Runna-inspired workout overview with focus-driven color, status actions,
/// per-exercise cards, notes, and a sticky Start Workout action.
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
        .navigationTitle(weekTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if let session {
                ToolbarItem(placement: .topBarTrailing) {
                    statusIndicator(for: session.status)
                }
            }
        }
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

    private var weekTitle: String {
        guard let plan = planStore.plan,
              let week = plan.weeks.first(where: { week in
                  week.sessions.contains { $0.id == sessionID }
              })
        else {
            return "Workout"
        }
        return "Week \(week.number)"
    }

    @ViewBuilder
    private func detailContent(for session: PlannedSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                WorkoutDetailHeroView(session: session)

                WorkoutDetailActionRow(
                    status: session.status,
                    isUpdatingStatus: isUpdatingStatus,
                    statusAction: { toggleSkipStatus(for: session) }
                )
                .padding(.horizontal, PluriSpacing.lg)

                Divider()

                VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                    if !session.equipmentNeeded.isEmpty {
                        equipmentSection(for: session)
                    }

                    exercisesSection(for: session)

                    if let errorMessage = viewModel?.errorMessage {
                        Text(errorMessage)
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.statusRedSoft)
                    }

                    notesButton
                }
                .padding(.horizontal, PluriSpacing.lg)
                .padding(.vertical, PluriSpacing.xl)
            }
        }
        .scrollIndicators(.hidden)
        // Let the hero wash continue under status/nav; content pads itself.
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom) {
            if session.status == .scheduled {
                startWorkoutBar
            }
        }
    }

    private var isUpdatingStatus: Bool {
        viewModel?.isSkipping == true || viewModel?.isUnskipping == true
    }

    private func statusIndicator(for status: WorkoutStatus) -> some View {
        Image(systemName: statusIndicatorImage(for: status))
            .font(.body.bold())
            .foregroundStyle(PluriColor.textPrimary)
            .frame(width: 44, height: 44)
            .overlay {
                RoundedRectangle(cornerRadius: PluriRadius.sm)
                    .stroke(PluriColor.textSecondary.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel(statusIndicatorLabel(for: status))
    }

    private func statusIndicatorImage(for status: WorkoutStatus) -> String {
        switch status {
        case .scheduled: ""
        case .skipped: "minus"
        case .completed: "checkmark"
        }
    }

    private func statusIndicatorLabel(for status: WorkoutStatus) -> String {
        switch status {
        case .scheduled: "Workout scheduled"
        case .skipped: "Workout skipped"
        case .completed: "Workout completed"
        }
    }

    private func equipmentSection(for session: PlannedSession) -> some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Label("Equipment", systemImage: "dumbbell")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)

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
        VStack(alignment: .leading, spacing: PluriSpacing.md) {
            Label("Exercises", systemImage: "list.bullet.rectangle")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)

            ForEach(session.exercises.enumerated(), id: \.element.id) { index, exercise in
                WorkoutDetailExerciseCard(
                    exercise: exercise,
                    number: index + 1,
                    workoutColor: WorkoutColorResolver.token(for: session).color
                )
            }
        }
    }

    private var notesButton: some View {
        Button {
            viewModel?.loadNotes()
            showsNotesSheet = true
        } label: {
            HStack {
                Label("Workout Notes", systemImage: "note.text")
                    .font(PluriFont.body)
                    .bold()
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(PluriColor.textPrimary)
            .padding(.horizontal, PluriSpacing.md)
            .frame(minHeight: 56)
            .background(PluriColor.bgSurface, in: .rect(cornerRadius: PluriRadius.md))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens workout notes")
    }

    private var startWorkoutBar: some View {
        Button("Start Workout", systemImage: "play.fill") {
            openWorkoutScreen()
        }
        .font(PluriFont.label)
        .bold()
        .foregroundStyle(.white)
        .padding(.horizontal, PluriSpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(.black, in: .capsule)
        .buttonStyle(.plain)
        .padding(.horizontal, PluriSpacing.lg)
        .padding(.vertical, PluriSpacing.sm)
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

    private func toggleSkipStatus(for session: PlannedSession) {
        switch session.status {
        case .scheduled:
            Task { await viewModel?.skip(using: planStore) }
        case .skipped:
            Task { await viewModel?.unskip(using: planStore) }
        case .completed:
            break
        }
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
