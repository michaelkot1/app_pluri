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
        #expect(router.insightsPath.isEmpty)
        #expect(router.communityPath.isEmpty)
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

    @Test("Home health tile sections deep-link into Insights (M5-04 / M5-15)")
    func healthTileSectionDeepLinks() {
        let router = MainRouter()
        let sections: [InsightsSection] = [.steps, .activeHeartRate, .calories, .sleep]

        for section in sections {
            router.selectTab(.home)
            router.openInsights(section: section)

            #expect(router.selectedTab == .insights)
            #expect(router.insightsSection == section)
            #expect(router.homePath.isEmpty)
        }
    }

    @Test("Home destinations push typed routes onto the Home path")
    func homePushes() {
        let router = MainRouter()
        let sessionID = UUID()

        router.openProfile()
        router.openNotifications()
        router.openCalendar()
        router.openWorkoutDetail(sessionID: sessionID)
        router.openWorkoutScreen(sessionID: sessionID)
        router.openWorkoutCompletion(
            planWorkoutID: sessionID,
            workoutSessionID: sessionID,
            elapsedSeconds: 90
        )
        router.openOutdoorRunStub()

        #expect(router.homePath == [
            .profile,
            .notifications,
            .calendar,
            .workoutDetail(sessionID: sessionID),
            .workoutScreen(sessionID: sessionID),
            .workoutCompletion(
                planWorkoutID: sessionID,
                workoutSessionID: sessionID,
                elapsedSeconds: 90
            ),
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

    // MARK: - Plan tab (M3-10..14)

    @Test("Plan destinations push typed routes onto the Plan path")
    func planPushes() {
        let router = MainRouter()
        let weekID = UUID()
        let sessionID = UUID()

        router.openWeekOverview(weekID: weekID)
        router.openPlanOverview()
        router.openRearrangeWorkouts()
        router.openConnectedApps()
        router.openManagePlan()
        router.openPlanWorkoutDetail(sessionID: sessionID)
        router.openPlanWorkoutScreen(sessionID: sessionID)
        router.openPlanWorkoutCompletion(
            planWorkoutID: sessionID,
            workoutSessionID: sessionID,
            elapsedSeconds: 120
        )

        #expect(router.planPath == [
            .weekOverview(weekID: weekID),
            .planOverview,
            .rearrangeWorkouts,
            .connectedApps,
            .managePlan,
            .workoutDetail(sessionID: sessionID),
            .workoutScreen(sessionID: sessionID),
            .workoutCompletion(
                planWorkoutID: sessionID,
                workoutSessionID: sessionID,
                elapsedSeconds: 120
            ),
        ])
        #expect(router.homePath.isEmpty)
    }

    @Test("Rearrange Workouts stays in the Plan stack; Home's Calendar stays in Home's")
    func calendarStaysInOriginatingStack() {
        let router = MainRouter()

        router.openRearrangeWorkouts()
        #expect(router.selectedTab == .plan)
        #expect(router.planPath == [.rearrangeWorkouts])
        #expect(router.homePath.isEmpty)

        router.openCalendar()
        #expect(router.selectedTab == .home)
        #expect(router.homePath == [.calendar])
        #expect(router.planPath == [.rearrangeWorkouts])
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

    @Test("Finishing Home completion pops Screen + Completion back to Detail")
    func finishHomeWorkoutCompletionPopsToDetail() {
        let router = MainRouter()
        let sessionID = UUID()

        router.openWorkoutDetail(sessionID: sessionID)
        router.openWorkoutScreen(sessionID: sessionID)
        router.openWorkoutCompletion(
            planWorkoutID: sessionID,
            workoutSessionID: sessionID,
            elapsedSeconds: 60
        )

        router.finishHomeWorkoutCompletion()

        #expect(router.homePath == [.workoutDetail(sessionID: sessionID)])
    }

    @Test("Finishing Plan completion pops Screen + Completion back to Detail")
    func finishPlanWorkoutCompletionPopsToDetail() {
        let router = MainRouter()
        let sessionID = UUID()

        router.openPlanWorkoutDetail(sessionID: sessionID)
        router.openPlanWorkoutScreen(sessionID: sessionID)
        router.openPlanWorkoutCompletion(
            planWorkoutID: sessionID,
            workoutSessionID: sessionID,
            elapsedSeconds: 60
        )

        router.finishPlanWorkoutCompletion()

        #expect(router.planPath == [.workoutDetail(sessionID: sessionID)])
    }

    // MARK: - Insights tab (M5-17)

    @Test("Insights destinations push typed routes onto the Insights path")
    func insightsPushes() {
        let router = MainRouter()
        let planWorkoutID = UUID()
        let sessionLogID = UUID()

        router.openInsightsWorkoutDetail(planWorkoutID: planWorkoutID)
        router.openInsightsCompletedSession(sessionID: sessionLogID)
        router.openInsightsWorkoutScreen(planWorkoutID: planWorkoutID)
        router.openInsightsWorkoutCompletion(
            planWorkoutID: planWorkoutID,
            workoutSessionID: sessionLogID,
            elapsedSeconds: 90
        )

        #expect(router.selectedTab == .insights)
        #expect(router.insightsPath == [
            .workoutDetail(planWorkoutID: planWorkoutID),
            .completedSession(sessionID: sessionLogID),
            .workoutScreen(planWorkoutID: planWorkoutID),
            .workoutCompletion(
                planWorkoutID: planWorkoutID,
                workoutSessionID: sessionLogID,
                elapsedSeconds: 90
            ),
        ])
        #expect(router.homePath.isEmpty)
        #expect(router.planPath.isEmpty)
    }

    @Test("Plan-linked Insights detail uses planWorkoutID, not session-log id")
    func insightsPlanDetailUsesPlanWorkoutID() {
        let router = MainRouter()
        let planWorkoutID = UUID()
        let sessionLogID = UUID()

        router.openInsightsWorkoutDetail(planWorkoutID: planWorkoutID)

        #expect(router.insightsPath == [.workoutDetail(planWorkoutID: planWorkoutID)])
        #expect(router.insightsPath != [.workoutDetail(planWorkoutID: sessionLogID)])
    }

    @Test("Manual Insights card opens completed-session route by session-log id")
    func insightsManualUsesCompletedSessionRoute() {
        let router = MainRouter()
        let sessionLogID = UUID()

        router.openInsightsCompletedSession(sessionID: sessionLogID)

        #expect(router.selectedTab == .insights)
        #expect(router.insightsPath == [.completedSession(sessionID: sessionLogID)])
    }

    @Test("Finishing Insights completion pops Screen + Completion back to Detail")
    func finishInsightsWorkoutCompletionPopsToDetail() {
        let router = MainRouter()
        let planWorkoutID = UUID()
        let sessionLogID = UUID()

        router.openInsightsWorkoutDetail(planWorkoutID: planWorkoutID)
        router.openInsightsWorkoutScreen(planWorkoutID: planWorkoutID)
        router.openInsightsWorkoutCompletion(
            planWorkoutID: planWorkoutID,
            workoutSessionID: sessionLogID,
            elapsedSeconds: 60
        )

        router.finishInsightsWorkoutCompletion()

        #expect(router.insightsPath == [.workoutDetail(planWorkoutID: planWorkoutID)])
    }

    @Test("Pushing an Insights route from another tab switches to Insights")
    func insightsPushSwitchesToInsights() {
        let router = MainRouter()
        router.selectTab(.home)
        let planWorkoutID = UUID()

        router.openInsightsWorkoutDetail(planWorkoutID: planWorkoutID)

        #expect(router.selectedTab == .insights)
        #expect(router.insightsPath == [.workoutDetail(planWorkoutID: planWorkoutID)])
    }
}

// MARK: - Community tab (M8-05)

extension MainRouterTests {
    @Test("Community search and calendar stay on the Community stack")
    func communityPushesStayOnCommunity() {
        let router = MainRouter()

        router.openCommunitySearch()
        #expect(router.selectedTab == .community)
        #expect(router.communityPath == [.search])
        #expect(router.homePath.isEmpty)

        router.openCommunityCalendar()
        #expect(router.selectedTab == .community)
        #expect(router.communityPath == [.search, .calendar])
        #expect(router.homePath.isEmpty)
    }
}
