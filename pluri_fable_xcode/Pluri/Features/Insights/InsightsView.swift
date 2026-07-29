import SwiftData
import SwiftUI

/// Insights root shell (M5-07 / SPEC §9): Performance | Workouts tabs, calendar
/// day filter (M5-13) and manual "+" logging (M5-12). Home health-tile deep
/// links land on Performance and retain `MainRouter.insightsSection` for the
/// Health chips (SPEC §14 #60 / #61 / #62).
struct InsightsView: View {
    @Environment(MainRouter.self) private var router
    @Environment(SwiftDataWorkoutSessionRepository.self) private var sessionRepository
    @Environment(LiveHealthKitService.self) private var healthKitService
    @Environment(PlanStore.self) private var planStore
    @Environment(SupabaseSyncEngine.self) private var syncEngine
    @Environment(SupabaseAuthService.self) private var authService
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: InsightsPrimaryTab = .performance
    @State private var performanceViewModel: InsightsPerformanceViewModel?
    @State private var workoutsViewModel: InsightsWorkoutsViewModel?
    @State private var showingDayFilter = false
    @State private var showingAddActivity = false
    @State private var saveErrorMessage: String?

    var body: some View {
        Group {
            if let performanceViewModel, let workoutsViewModel {
                tabContent(
                    performanceViewModel: performanceViewModel,
                    workoutsViewModel: workoutsViewModel
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PluriColor.bgCanvas)
        .navigationTitle("Insights")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Calendar", systemImage: "calendar") {
                    showingDayFilter = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add activity", systemImage: "plus") {
                    showingAddActivity = true
                }
            }
        }
        .sheet(isPresented: $showingDayFilter) {
            InsightsDayFilterSheet(
                initialDate: workoutsViewModel?.dayFilter ?? .now,
                onConfirm: { date in
                    applyDayFilter(date)
                },
                onClear: {
                    clearDayFilter()
                }
            )
        }
        .sheet(isPresented: $showingAddActivity) {
            ManualActivityLoggingSheet(
                usesImperialUnits: planStore.profile?.units == "imperial"
            ) { draft in
                saveManualActivity(draft)
            }
        }
        .alert("Couldn't save activity", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .onAppear {
            ensureViewModels()
            landOnPerformanceForDeepLink()
            refreshAll()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshAll()
            }
        }
        .onChange(of: router.selectedTab) { _, tab in
            if tab == .insights {
                landOnPerformanceForDeepLink()
                refreshAll()
            }
        }
        // A grant made from Profile / Connected Apps should light Insights up on return.
        .onChange(of: healthKitService.authorizationStatus) { _, _ in
            refreshAll()
        }
        .onChange(of: router.insightsSection) { _, _ in
            if router.selectedTab == .insights {
                landOnPerformanceForDeepLink()
            }
        }
    }

    @ViewBuilder
    private func tabContent(
        performanceViewModel: InsightsPerformanceViewModel,
        workoutsViewModel: InsightsWorkoutsViewModel
    ) -> some View {
        VStack(spacing: 0) {
            InsightsPrimaryTabPicker(selectedTab: $selectedTab)
                .padding(.horizontal, PluriSpacing.lg)
                .padding(.top, PluriSpacing.sm)

            switch selectedTab {
            case .performance:
                InsightsPerformanceView(
                    viewModel: performanceViewModel,
                    healthSection: router.insightsSection,
                    onSelectHealthSection: { router.insightsSection = $0 }
                )
            case .workouts:
                InsightsWorkoutsTabView(viewModel: workoutsViewModel)
            }
        }
    }

    private func ensureViewModels() {
        if performanceViewModel == nil {
            performanceViewModel = InsightsPerformanceViewModel(
                repository: sessionRepository,
                healthKit: healthKitService
            )
        }
        if workoutsViewModel == nil {
            workoutsViewModel = InsightsWorkoutsViewModel(
                repository: sessionRepository,
                planStore: planStore
            )
        }
    }

    private func landOnPerformanceForDeepLink() {
        selectedTab = .performance
    }

    private func refreshAll() {
        performanceViewModel?.refresh()
        workoutsViewModel?.refresh()
    }

    private func applyDayFilter(_ date: Date) {
        ensureViewModels()
        workoutsViewModel?.applyDayFilter(date)
        performanceViewModel?.snapWeek(to: date)
        selectedTab = .workouts
    }

    private func clearDayFilter() {
        workoutsViewModel?.clearDayFilter()
    }

    private func saveManualActivity(_ draft: ManualActivityDraft) {
        guard let userId = authService.appUserID.flatMap(UUID.init(uuidString:)) else {
            saveErrorMessage = "Sign in to log an activity."
            return
        }
        do {
            let session = try sessionRepository.createManualActivity(
                userId: userId,
                activityType: draft.activityType.storageValue,
                startedAt: draft.startedAt,
                durationSeconds: draft.durationSeconds,
                distanceMeters: draft.distanceMeters,
                notes: draft.notes
            )
            syncEngine.enqueueSession(id: session.id)
            selectedTab = .workouts
            refreshAll()
        } catch {
            saveErrorMessage = "Couldn't save that activity. Please try again."
        }
    }
}

// MARK: - Tab picker

private struct InsightsPrimaryTabPicker: View {
    @Binding var selectedTab: InsightsPrimaryTab

    var body: some View {
        HStack(spacing: PluriSpacing.sm) {
            ForEach(InsightsPrimaryTab.allCases) { tab in
                PluriChip(
                    title: LocalizedStringKey(tab.title),
                    isSelected: tab == selectedTab
                ) {
                    selectedTab = tab
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Insights tabs")
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Schema([
            WorkoutSessionRecord.self,
            SetLogRecord.self,
        ]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let supabase = SupabaseService()
    NavigationStack {
        InsightsView()
    }
    .environment(MainRouter())
    .environment(SwiftDataWorkoutSessionRepository(modelContext: container.mainContext))
    .environment(LiveHealthKitService())
    .environment(PlanStore(mutationService: MockPlanMutationService()))
    .environment(
        SupabaseSyncEngine(
            modelContext: container.mainContext,
            supabaseService: supabase
        )
    )
    .environment(SupabaseAuthService(supabaseService: supabase))
    .modelContainer(container)
}
