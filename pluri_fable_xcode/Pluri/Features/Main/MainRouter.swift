import Foundation
import Observation

/// Navigation state for the Main TabView (M3-06): selected tab, the Home
/// tab's typed navigation path, and the Insights section requested by a
/// Home health-tile deep link (PLAN §1.2).
///
/// Deliberately separate from the root `AppRouter` (which owns app phases —
/// SPEC §14 #41): this router only exists while the Main shell is on screen.
/// Owned by `MainTabView` as `@State` and injected via `.environment`.
/// Tabs other than Home gain their own paths when their real content lands
/// (M3-10+).
@MainActor
@Observable
final class MainRouter {
    var selectedTab: MainTab = .home

    /// The Home tab's `NavigationStack` path.
    var homePath: [HomeRoute] = []

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

    private func pushOnHome(_ route: HomeRoute) {
        selectedTab = .home
        homePath.append(route)
    }
}
