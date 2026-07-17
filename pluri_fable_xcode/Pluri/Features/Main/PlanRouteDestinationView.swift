import SwiftUI

/// Resolves a pushed `PlanRoute` to its destination view (M3-10..14). Week
/// Overview (§6.3), Plan Overview (§6.1), Rearrange Workouts (the shared
/// §5.4 Calendar page), Connected Apps, and Manage Plan (§6.2) are all real;
/// Workout Detail is the shared M4 stub.
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
        case .planOverview:
            PlanOverviewView()
        case .rearrangeWorkouts:
            CalendarView(title: "Rearrange Workouts")
        case .connectedApps:
            ConnectedAppsView()
        case .managePlan:
            ManagePlanView()
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
