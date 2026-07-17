import Foundation
import Observation

/// Navigation state for the Main TabView (M3-06): selected tab, the Home and
/// Plan tabs' typed navigation paths, and the Insights section requested by a
/// Home health-tile deep link (PLAN §1.2).
///
/// Deliberately separate from the root `AppRouter` (which owns app phases —
/// SPEC §14 #41): this router only exists while the Main shell is on screen.
/// Owned by `MainTabView` as `@State` and injected via `.environment`.
/// Remaining tabs gain their own paths when their real content lands.
@MainActor
@Observable
final class MainRouter {
    var selectedTab: MainTab = .home

    /// The Home tab's `NavigationStack` path.
    var homePath: [HomeRoute] = []

    /// The Plan tab's `NavigationStack` path (M3-10/11).
    var planPath: [PlanRoute] = []

    /// The Insights section a Home health tile asked for; the Insights
    /// placeholder highlights it (M3-08 deep link).
    var insightsSection: InsightsSection = .general

    func selectTab(_ tab: MainTab) {
        selectedTab = tab
    }

    /// Cross-tab jump from a Home health tile into the Insights placeholder.
    func openInsights(section: InsightsSection) {
        insightsSection = section
        selectedTab = .insights
    }

    func openProfile() {
        pushOnHome(.profile)
    }

    func openNotifications() {
        pushOnHome(.notifications)
    }

    func openCalendar() {
        pushOnHome(.calendarStub)
    }

    func openWorkoutDetail(sessionID: UUID) {
        pushOnHome(.workoutDetail(sessionID: sessionID))
    }

    func openOutdoorRunStub() {
        pushOnHome(.outdoorRunStub)
    }

    // MARK: - Plan tab (M3-10/11)

    func openWeekOverview(weekID: UUID) {
        pushOnPlan(.weekOverview(weekID: weekID))
    }

    func openPlanOverviewStub() {
        pushOnPlan(.planOverviewStub)
    }

    func openRearrangeWorkoutsStub() {
        pushOnPlan(.rearrangeWorkoutsStub)
    }

    func openConnectedAppsStub() {
        pushOnPlan(.connectedAppsStub)
    }

    func openManagePlanStub() {
        pushOnPlan(.managePlanStub)
    }

    /// Workout Detail pushed inside the Plan tab's stack — unlike
    /// `openWorkoutDetail`, which deliberately jumps to the Home tab.
    func openPlanWorkoutDetail(sessionID: UUID) {
        pushOnPlan(.workoutDetail(sessionID: sessionID))
    }

    private func pushOnHome(_ route: HomeRoute) {
        selectedTab = .home
        homePath.append(route)
    }

    private func pushOnPlan(_ route: PlanRoute) {
        selectedTab = .plan
        planPath.append(route)
    }
}
