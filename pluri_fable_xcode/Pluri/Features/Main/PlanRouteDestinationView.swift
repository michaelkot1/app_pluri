import SwiftUI

/// Resolves a pushed `PlanRoute` to its destination view (M3-10/11). Week
/// Overview is the real §6.3 page fed from the live `PlanStore`; Plan
/// Overview, Rearrange Workouts, Connected Apps, and Manage Plan are honest
/// stubs until M3-12/13/14, and Workout Detail is the shared M4 stub.
struct PlanRouteDestinationView: View {
    var route: PlanRoute

    @Environment(PlanStore.self) private var planStore

    var body: some View {
        switch route {
        case .weekOverview(let weekID):
            if let week = week(withID: weekID) {
                WeekOverviewView(week: week)
            } else {
                MainTabPlaceholderView(
                    title: "Week",
                    systemImage: "calendar",
                    message: "We couldn't find that week in your plan. Head back and pick a week card."
                )
            }
        case .planOverviewStub:
            MainTabPlaceholderView(
                title: "Plan Overview",
                systemImage: "info.circle",
                message: "What each workout color means, how your Pluri Score works, and how to talk to Pluri arrive in a later update."
            )
        case .rearrangeWorkoutsStub:
            MainTabPlaceholderView(
                title: "Rearrange Workouts",
                systemImage: "arrow.up.arrow.down",
                message: "The full calendar — moving workouts and adding to empty days — arrives in a later update."
            )
        case .connectedAppsStub:
            MainTabPlaceholderView(
                title: "Connected Apps",
                systemImage: "applewatch",
                message: "Connected apps and devices — Apple Health, your watch, and more — arrive in a later update."
            )
        case .managePlanStub:
            MainTabPlaceholderView(
                title: "Manage Plan",
                systemImage: "slider.horizontal.3",
                message: "Editing your goal, dates, training days, and workout length arrives in a later update."
            )
        case .workoutDetail(let sessionID):
            WorkoutDetailStubView(session: session(withID: sessionID))
        }
    }

    private func week(withID id: UUID) -> PlanWeek? {
        planStore.plan?.weeks.first { $0.id == id }
    }

    private func session(withID id: UUID) -> PlannedSession? {
        guard let plan = planStore.plan else { return nil }
        return PlanMutator.session(withID: id, in: plan)
    }
}
