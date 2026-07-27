import Foundation
import Observation

/// Navigation state for the Main TabView (M3-06 / M5-17 / M7-08): selected tab,
/// the Home / Plan / Insights / Recipe tabs' typed navigation paths, and the
/// Insights section requested by a Home health-tile deep link (PLAN §1.2).
///
/// Deliberately separate from the root `AppRouter` (which owns app phases —
/// SPEC §14 #41): this router only exists while the Main shell is on screen.
/// Owned by `MainTabView` as `@State` and injected via `.environment`.
@MainActor
@Observable
final class MainRouter {
    var selectedTab: MainTab = .home

    /// The Home tab's `NavigationStack` path.
    var homePath: [HomeRoute] = []

    /// The Plan tab's `NavigationStack` path (M3-10/11).
    var planPath: [PlanRoute] = []

    /// The Insights tab's `NavigationStack` path (M5-17 / SPEC §14 #64).
    var insightsPath: [InsightsRoute] = []

    /// The Recipe tab's `NavigationStack` path (M7-08/09).
    var recipePath: [RecipeRoute] = []

    /// Health subsection a Home tile asked for; Insights lands on Performance
    /// and highlights the matching Health chip (M3-08 / M5-07 / M5-10 / SPEC §14 #61).
    var insightsSection: InsightsSection = .general

    func selectTab(_ tab: MainTab) {
        selectedTab = tab
    }

    /// Cross-tab jump from a Home health tile into Insights Performance.
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

    /// The real Calendar page (M3-13) pushed inside the Home stack.
    func openCalendar() {
        pushOnHome(.calendar)
    }

    func openWorkoutDetail(sessionID: UUID) {
        pushOnHome(.workoutDetail(sessionID: sessionID))
    }

    /// Live Workout Screen (M4-07+).
    func openWorkoutScreen(sessionID: UUID) {
        pushOnHome(.workoutScreen(sessionID: sessionID))
    }

    /// Completion summary after Stop / hold-to-finish (M4-12).
    func openWorkoutCompletion(
        planWorkoutID: UUID,
        workoutSessionID: UUID,
        elapsedSeconds: Int
    ) {
        pushOnHome(
            .workoutCompletion(
                planWorkoutID: planWorkoutID,
                workoutSessionID: workoutSessionID,
                elapsedSeconds: elapsedSeconds
            )
        )
    }

    /// After Save / Discard: pop Screen + Completion so the user lands on Detail (SPEC §14 #56).
    func finishHomeWorkoutCompletion() {
        while let last = homePath.last {
            switch last {
            case .workoutCompletion, .workoutScreen:
                homePath.removeLast()
            default:
                return
            }
        }
    }

    func openOutdoorRunStub() {
        pushOnHome(.outdoorRunStub)
    }

    // MARK: - Plan tab (M3-10..14)

    func openWeekOverview(weekID: UUID) {
        pushOnPlan(.weekOverview(weekID: weekID))
    }

    func openPlanOverview() {
        pushOnPlan(.planOverview)
    }

    /// The shared Calendar page as "Rearrange Workouts" (§5.4/§6), pushed
    /// inside the Plan stack — no cross-tab jump.
    func openRearrangeWorkouts() {
        pushOnPlan(.rearrangeWorkouts)
    }

    func openConnectedApps() {
        pushOnPlan(.connectedApps)
    }

    func openManagePlan() {
        pushOnPlan(.managePlan)
    }

    /// Workout Detail pushed inside the Plan tab's stack — unlike
    /// `openWorkoutDetail`, which deliberately jumps to the Home tab.
    func openPlanWorkoutDetail(sessionID: UUID) {
        pushOnPlan(.workoutDetail(sessionID: sessionID))
    }

    /// Workout Screen pushed inside the Plan stack (keeps stack affinity).
    func openPlanWorkoutScreen(sessionID: UUID) {
        pushOnPlan(.workoutScreen(sessionID: sessionID))
    }

    /// Completion summary inside the Plan stack (M4-12).
    func openPlanWorkoutCompletion(
        planWorkoutID: UUID,
        workoutSessionID: UUID,
        elapsedSeconds: Int
    ) {
        pushOnPlan(
            .workoutCompletion(
                planWorkoutID: planWorkoutID,
                workoutSessionID: workoutSessionID,
                elapsedSeconds: elapsedSeconds
            )
        )
    }

    /// After Save / Discard: pop Screen + Completion so the user lands on Detail (SPEC §14 #56).
    func finishPlanWorkoutCompletion() {
        while let last = planPath.last {
            switch last {
            case .workoutCompletion, .workoutScreen:
                planPath.removeLast()
            default:
                return
            }
        }
    }

    // MARK: - Insights tab (M5-17)

    /// Plan-linked Workout Detail inside the Insights stack — uses
    /// `planWorkoutID` (`PlannedSession.id`), never the session-log id.
    func openInsightsWorkoutDetail(planWorkoutID: UUID) {
        pushOnInsights(.workoutDetail(planWorkoutID: planWorkoutID))
    }

    /// Manual / completed session summary inside the Insights stack.
    func openInsightsCompletedSession(sessionID: UUID) {
        pushOnInsights(.completedSession(sessionID: sessionID))
    }

    /// Workout Screen pushed inside the Insights stack (keeps stack affinity).
    func openInsightsWorkoutScreen(planWorkoutID: UUID) {
        pushOnInsights(.workoutScreen(planWorkoutID: planWorkoutID))
    }

    /// Completion summary inside the Insights stack.
    func openInsightsWorkoutCompletion(
        planWorkoutID: UUID,
        workoutSessionID: UUID,
        elapsedSeconds: Int
    ) {
        pushOnInsights(
            .workoutCompletion(
                planWorkoutID: planWorkoutID,
                workoutSessionID: workoutSessionID,
                elapsedSeconds: elapsedSeconds
            )
        )
    }

    /// After Save / Discard: pop Screen + Completion so the user lands on Detail.
    func finishInsightsWorkoutCompletion() {
        while let last = insightsPath.last {
            switch last {
            case .workoutCompletion, .workoutScreen:
                insightsPath.removeLast()
            default:
                return
            }
        }
    }

    // MARK: - Recipe tab (M7-08/09)

    func openRecipeDetail(mealID: String) {
        selectedTab = .recipe
        recipePath.append(.detail(mealID: mealID))
    }

    private func pushOnHome(_ route: HomeRoute) {
        selectedTab = .home
        homePath.append(route)
    }

    private func pushOnPlan(_ route: PlanRoute) {
        selectedTab = .plan
        planPath.append(route)
    }

    private func pushOnInsights(_ route: InsightsRoute) {
        selectedTab = .insights
        insightsPath.append(route)
    }
}
