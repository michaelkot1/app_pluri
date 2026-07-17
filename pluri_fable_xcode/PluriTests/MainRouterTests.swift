import Foundation
import Testing
@testable import Pluri

/// M3-06/10/11 — the Main shell's navigation state: programmatic tab
/// selection, typed Home- and Plan-path pushes, and the health-tile deep
/// link into Insights.
@Suite("MainRouter")
@MainActor
struct MainRouterTests {
    @Test("Router starts on Home with empty paths and general Insights")
    func initialState() {
        let router = MainRouter()

        #expect(router.selectedTab == .home)
        #expect(router.homePath.isEmpty)
        #expect(router.planPath.isEmpty)
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

    // MARK: - Plan tab (M3-10/11)

    @Test("Plan destinations push typed routes onto the Plan path")
    func planPushes() {
        let router = MainRouter()
        let weekID = UUID()
        let sessionID = UUID()

        router.openWeekOverview(weekID: weekID)
        router.openPlanOverviewStub()
        router.openRearrangeWorkoutsStub()
        router.openConnectedAppsStub()
        router.openManagePlanStub()
        router.openPlanWorkoutDetail(sessionID: sessionID)

        #expect(router.planPath == [
            .weekOverview(weekID: weekID),
            .planOverviewStub,
            .rearrangeWorkoutsStub,
            .connectedAppsStub,
            .managePlanStub,
            .workoutDetail(sessionID: sessionID),
        ])
        #expect(router.homePath.isEmpty)
    }

    @Test("Pushing a Plan route from another tab switches to Plan")
    func planPushSwitchesToPlan() {
        let router = MainRouter()
        let weekID = UUID()

        router.openWeekOverview(weekID: weekID)

        #expect(router.selectedTab == .plan)
        #expect(router.planPath == [.weekOverview(weekID: weekID)])
    }

    @Test("Plan workout detail stays in the Plan stack, unlike Home's")
    func planWorkoutDetailStaysOnPlan() {
        let router = MainRouter()
        router.selectTab(.plan)
        let sessionID = UUID()

        router.openPlanWorkoutDetail(sessionID: sessionID)

        #expect(router.selectedTab == .plan)
        #expect(router.planPath == [.workoutDetail(sessionID: sessionID)])
        #expect(router.homePath.isEmpty)

        router.openWorkoutDetail(sessionID: sessionID)

        #expect(router.selectedTab == .home)
        #expect(router.homePath == [.workoutDetail(sessionID: sessionID)])
    }
}
