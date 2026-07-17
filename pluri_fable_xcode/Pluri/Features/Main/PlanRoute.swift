import Foundation

/// Typed destinations pushable from the Plan tab's `NavigationStack`
/// (M3-10..14). Week Overview, Plan Overview, Rearrange Workouts (the shared
/// Calendar page), Connected Apps, and Manage Plan are real; Workout Detail
/// is the shared M4 stub.
enum PlanRoute: Hashable, Sendable {
    case weekOverview(weekID: UUID)
    case planOverview
    case rearrangeWorkouts
    case connectedApps
    case managePlan
    case workoutDetail(sessionID: UUID)
}
