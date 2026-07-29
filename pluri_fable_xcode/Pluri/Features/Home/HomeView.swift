import SwiftUI

/// The real Home screen (M3-07..09 / M5-04..06 / SPEC §5): top bar with
/// Profile / Notifications / Calendar, month summary + calendar strip with
/// workout dots, the selected day's workouts, live Pluri Score, Today's
/// Health tiles, and the floating Record Workout menu.
///
/// Observes the shared `PlanStore` (M3-04) and navigates through the
/// `MainRouter`'s typed Home path (M3-06). Health + score refresh on appear,
/// foreground, plan-status changes, and foreground HealthKit observer updates
/// (SPEC §14 #57d / #65).
struct HomeView: View {
    @Environment(PlanStore.self) private var planStore
    @Environment(MainRouter.self) private var router
    @Environment(LiveHealthKitService.self) private var healthKitService
    @Environment(SupabaseAuthService.self) private var authService
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = HomeViewModel()
    @State private var showsRecordMenu = false
    @State private var goalMetric: HomeHealthMetricPresentation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                switch planStore.loadState {
                case .loading:
                    HomeLoadingIndicator()
                case .failed:
                    HomeMessageCard(
                        title: "We couldn't load your plan",
                        message: "Check your connection and relaunch — your plan is safe on your account."
                    )
                case .empty:
                    HomeMessageCard(
                        title: "No active plan yet",
                        message: "Create a plan to see your weekly schedule and start planned workouts here."
                    )
                case .ready:
                    HomePlanContent(viewModel: viewModel)
                }

                HomePluriScoreHero(presentation: viewModel.scorePresentation)

                HomeHealthMetricsGrid(
                    metrics: viewModel.healthMetrics,
                    onOpen: { section in
                        router.openInsights(section: section)
                    },
                    onEditGoal: { metric in
                        goalMetric = metric
                    }
                )
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.top, PluriSpacing.lg)
            // Keep the last card clear of the floating button.
            .padding(.bottom, PluriSpacing.xxl + PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .background(PluriColor.bgCanvas)
        .navigationTitle(greeting)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Profile", systemImage: "person.crop.circle") {
                    router.openProfile()
                }
                .foregroundStyle(PluriColor.brandOrange)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Notifications", systemImage: "bell") {
                    router.openNotifications()
                }
                .foregroundStyle(PluriColor.brandOrange)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Calendar", systemImage: "calendar") {
                    router.openCalendar()
                }
                .foregroundStyle(PluriColor.brandOrange)
            }
        }
        .overlay(alignment: .bottom) {
            if !recordOptions.isEmpty {
                HomeRecordWorkoutButton {
                    showsRecordMenu = true
                }
                .padding(.bottom, PluriSpacing.md)
            }
        }
        .confirmationDialog("Record Workout", isPresented: $showsRecordMenu, titleVisibility: .visible) {
            ForEach(recordOptions) { option in
                HomeRecordOptionButton(option: option)
            }
        }
        .sheet(item: $goalMetric) { metric in
            HomeHealthGoalEditor(metric: metric) { target in
                guard let kind = metric.kind.goalKind else { return }
                viewModel.setHealthGoal(target, for: kind, userID: authService.appUserID)
                Task { await refreshHealthAndScore() }
            } onClear: {
                guard let kind = metric.kind.goalKind else { return }
                viewModel.clearHealthGoal(for: kind, userID: authService.appUserID)
                Task { await refreshHealthAndScore() }
            }
        }
        .task(id: scoreRefreshToken) {
            await refreshHealthAndScore()
            configureHealthObserver()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshHealthAndScore() }
            configureHealthObserver()
        }
        // Connecting from Profile / Connected Apps happens without leaving the app,
        // so re-read as soon as the grant lands instead of waiting for a relaunch.
        .onChange(of: healthKitService.authorizationStatus) { _, _ in
            Task { await refreshHealthAndScore() }
            configureHealthObserver()
        }
        // Returning to the Home tab doesn't re-run `task(id:)`, which would otherwise
        // leave today's step total frozen at whatever it was when Home last refreshed.
        .onChange(of: router.selectedTab) { _, tab in
            guard tab == .home else { return }
            Task { await refreshHealthAndScore() }
        }
        .onDisappear {
            healthKitService.stopObservingHealthChanges()
        }
    }

    private var greeting: String {
        if let name = planStore.profile?.displayName, !name.isEmpty {
            "Hi, \(name)"
        } else {
            "Home"
        }
    }

    /// Changes when any plan session status changes so score refreshes after Save / skip.
    private var scoreRefreshToken: String {
        let sessions = planStore.plan?.weeks.flatMap(\.sessions) ?? []
        return HomeViewModel.scoreRefreshToken(sessions: sessions)
    }

    private var recordOptions: [HomeRecordOption] {
        viewModel.recordOptions(
            todaysSessions: planStore.todaysSessions,
            flexibleSessions: planStore.currentFlexiblePool
        )
    }

    private func refreshHealthAndScore() async {
        await viewModel.refreshHealthMetrics(
            using: healthKitService,
            userID: authService.appUserID,
            asOf: planStore.now()
        )
        let sessions = planStore.plan?.weeks.flatMap(\.sessions) ?? []
        await viewModel.refreshPluriScore(
            sessions: sessions,
            healthKit: healthKitService,
            userID: authService.appUserID,
            asOf: planStore.now()
        )
    }

    /// Foreground HKObserverQuery → coalesced tile + score refresh (M5-18).
    /// Tears down when unauthorized / unavailable; no background-delivery entitlement.
    private func configureHealthObserver() {
        guard healthKitService.authorizationStatus == .authorized else {
            healthKitService.stopObservingHealthChanges()
            return
        }
        healthKitService.startObservingHealthChanges {
            Task { await refreshHealthAndScore() }
        }
    }
}

/// Unified schedule card for the ready state.
private struct HomePlanContent: View {
    var viewModel: HomeViewModel

    @Environment(PlanStore.self) private var planStore
    @Environment(MainRouter.self) private var router

    var body: some View {
        let today = planStore.today
        let selectedDay = viewModel.resolvedSelectedDay(today: today)
        let sessionsByDay = planStore.sessionsByDay

        HomeScheduleCard(
            summary: viewModel.monthSummary(containing: today, sessionsByDay: sessionsByDay),
            days: viewModel.weekDays(containing: selectedDay),
            selectedDay: selectedDay,
            today: today,
            sessionsByDay: sessionsByDay,
            selectedSessions: planStore.sessions(on: selectedDay),
            flexibleSessions: planStore.currentFlexiblePool,
            onSelectDay: { day in
                viewModel.select(day: day)
            },
            onViewCalendar: {
                router.openCalendar()
            }
        )
    }
}

/// One Record Workout menu choice, routed through the `MainRouter` (M3-09):
/// planned workout → Detail (M4-05). No stub destinations are offered.
private struct HomeRecordOptionButton: View {
    var option: HomeRecordOption

    @Environment(MainRouter.self) private var router

    var body: some View {
        switch option {
        case .scheduledWorkout(let session):
            Button(session.title) {
                router.openWorkoutDetail(sessionID: session.id)
            }
        }
    }
}

/// Centered spinner while the router is still resolving plan content.
private struct HomeLoadingIndicator: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView("Loading your plan…")
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
            Spacer()
        }
        .padding(.vertical, PluriSpacing.xl)
    }
}

#Preview("Ready") {
    NavigationStack {
        HomeView()
    }
    .environment(HomePreviewData.readyStore())
    .environment(MainRouter())
    .environment(LiveHealthKitService())
    .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
}

#Preview("Flexible") {
    NavigationStack {
        HomeView()
    }
    .environment(HomePreviewData.flexibleStore())
    .environment(MainRouter())
    .environment(LiveHealthKitService())
    .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
}

#Preview("Empty") {
    NavigationStack {
        HomeView()
    }
    .environment(HomePreviewData.emptyStore())
    .environment(MainRouter())
    .environment(LiveHealthKitService())
    .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
}

#Preview("Failed") {
    NavigationStack {
        HomeView()
    }
    .environment(HomePreviewData.failedStore())
    .environment(MainRouter())
    .environment(LiveHealthKitService())
    .environment(SupabaseAuthService(supabaseService: SupabaseService(), restoreOnLaunch: false))
}
