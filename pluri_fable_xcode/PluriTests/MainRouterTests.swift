import Foundation
import Testing
@testable import Pluri

/// M3-06 — the Main shell's navigation state: programmatic tab selection,
/// typed Home-path pushes, and the health-tile deep link into Insights.
@Suite("MainRouter")
@MainActor
struct MainRouterTests {
    @Test("Router starts on Home with an empty path and general Insights")
    func initialState() {
        let router = MainRouter()

        #expect(router.selectedTab == .home)
        #expect(router.homePath.isEmpty)
        #expect(router.insightsSection == .general)
    }

    @Test("Selecting a tab updates the selection")
    func tabSelection() {
        let router = MainRouter()

        router.selectTab(.plan)
        #expect(router.selectedTab == .plan)
    }

    @Test("Opening Insights switches tab and records the requested section")
    func insightsDeepLink() {
        let router = MainRouter()

        router.openInsights(section: .sleep)

        #expect(router.selectedTab == .insights)
        #expect(router.insightsSection == .sleep)
        #expect(router.homePath.isEmpty)
    }

    @Test("Home destinations push typed routes onto the Home path")
    func homePushes() {
        let router = MainRouter()
        let sessionID = UUID()

        router.openProfile()
        router.openNotifications()
        router.openCalendar()
        router.openWorkoutDetail(sessionID: sessionID)
        router.openOutdoorRunStub()

        #expect(router.homePath == [
            .profile,
            .notifications,
            .calendarStub,
            .workoutDetail(sessionID: sessionID),
            .outdoorRunStub,
        ])
    }

    @Test("Pushing a Home route from another tab returns to Home")
    func homePushSwitchesBackToHome() {
        let router = MainRouter()
        router.selectTab(.insights)

        router.openProfile()

        #expect(router.selectedTab == .home)
        #expect(router.homePath == [.profile])
    }
}
