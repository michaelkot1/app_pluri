import SwiftUI

/// The real Home screen (M3-07..09 / SPEC §5): top bar with Profile /
/// Notifications / Calendar, month summary + calendar strip with workout
/// dots, the selected day's workouts, the sample Pluri Score card, Today's
/// Health placeholder tiles, and the floating Record Workout menu.
///
/// Observes the shared `PlanStore` (M3-04) and navigates through the
/// `MainRouter`'s typed Home path (M3-06).
struct HomeView: View {
    @Environment(PlanStore.self) private var planStore
    @Environment(MainRouter.self) private var router

    @State private var viewModel = HomeViewModel()
    @State private var showsRecordMenu = false

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
                        message: "We couldn't find an active plan on your account. Plan tools arrive with the next update."
                    )
                case .ready:
                    HomePlanContent(viewModel: viewModel)
                }

                HomePluriScoreCard()

                HomeHealthTiles { section in
                    router.openInsights(section: section)
                }
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
            HomeRecordWorkoutButton {
                showsRecordMenu = true
            }
            .padding(.bottom, PluriSpacing.md)
        }
        .confirmationDialog("Record Workout", isPresented: $showsRecordMenu, titleVisibility: .visible) {
            ForEach(viewModel.recordOptions(todaysSessions: planStore.todaysSessions)) { option in
                HomeRecordOptionButton(option: option)
            }
        }
    }

    private var greeting: String {
        if let name = planStore.profile?.displayName, !name.isEmpty {
            "Hi, \(name)"
        } else {
            "Home"
        }
    }
}

/// Month header + calendar strip + selected-day card for the ready state.
private struct HomePlanContent: View {
    var viewModel: HomeViewModel

    @Environment(PlanStore.self) private var planStore

    var body: some View {
        let today = planStore.today
        let selectedDay = viewModel.resolvedSelectedDay(today: today)
        let sessionsByDay = planStore.sessionsByDay

        VStack(alignment: .leading, spacing: PluriSpacing.md) {
            HomeMonthHeader(
                summary: viewModel.monthSummary(containing: today, sessionsByDay: sessionsByDay)
            )

            HomeCalendarStrip(
                days: viewModel.monthDays(containing: today),
                selectedDay: selectedDay,
                today: today,
                sessionsByDay: sessionsByDay
            ) { day in
                viewModel.select(day: day)
            }

            HomeSelectedDayCard(
                day: selectedDay,
                isToday: Calendar.current.isDate(selectedDay, inSameDayAs: today),
                sessions: planStore.sessions(on: selectedDay)
            )
        }
    }
}

/// One Record Workout menu choice, routed through the `MainRouter` (M3-09):
/// today's scheduled workout → Detail (M4-05); Outdoor Run stays a stub.
private struct HomeRecordOptionButton: View {
    var option: HomeRecordOption

    @Environment(MainRouter.self) private var router

    var body: some View {
        switch option {
        case .scheduledWorkout(let session):
            Button(session.title) {
                router.openWorkoutDetail(sessionID: session.id)
            }
        case .outdoorRun:
            Button("Outdoor Run") {
                router.openOutdoorRunStub()
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
}

#Preview("Flexible") {
    NavigationStack {
        HomeView()
    }
    .environment(HomePreviewData.flexibleStore())
    .environment(MainRouter())
}

#Preview("Empty") {
    NavigationStack {
        HomeView()
    }
    .environment(HomePreviewData.emptyStore())
    .environment(MainRouter())
}

#Preview("Failed") {
    NavigationStack {
        HomeView()
    }
    .environment(HomePreviewData.failedStore())
    .environment(MainRouter())
}
