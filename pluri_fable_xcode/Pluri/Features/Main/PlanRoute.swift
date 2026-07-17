import Foundation

/// Typed destinations pushable from the Plan tab's `NavigationStack`
/// (M3-10/11). Week Overview is real; Plan Overview, Rearrange Workouts,
/// Connected Apps, and Manage Plan are honest stubs until M3-12/13/14, and
/// Workout Detail is the shared M4 stub.
enum PlanRoute: Hashable, Sendable {
    case weekOverview(weekID: UUID)
    case planOverviewStub
    case rearrangeWorkoutsStub
    case connectedAppsStub
    case managePlanStub
    case workoutDetail(sessionID: UUID)
}
