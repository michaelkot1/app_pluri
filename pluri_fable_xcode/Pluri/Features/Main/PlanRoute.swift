import Foundation

/// Typed destinations pushable from the Plan tab's `NavigationStack`
/// (M3-10..14). Week Overview, Plan Overview, Rearrange Workouts (the shared
/// Calendar page), Connected Apps, and Manage Plan are real; Workout Detail
/// is live (M4-05); Workout Screen is a thin stub until M4-07.
enum PlanRoute: Hashable, Sendable {
    case weekOverview(weekID: UUID)
    case planOverview
    case rearrangeWorkouts
    case connectedApps
    case managePlan
    case workoutDetail(sessionID: UUID)
    case workoutScreen(sessionID: UUID)
    /// Completion stub until M4-12 (name + elapsed only).
    case workoutCompletion(planWorkoutID: UUID, workoutSessionID: UUID, elapsedSeconds: Int)
}
