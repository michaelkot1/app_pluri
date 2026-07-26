import Foundation

/// Typed destinations pushable from the Insights tab's `NavigationStack`
/// (M5-17 / SPEC §14 #64). Plan-linked cards open Workout Detail with
/// `planWorkoutId`; manual / session-only cards open completed-session detail
/// (never pass `WorkoutSessionRecord.id` into `WorkoutDetailView`).
enum InsightsRoute: Hashable, Sendable {
    /// Plan workout Detail — `planWorkoutID` is `PlannedSession.id`, not session-log id.
    case workoutDetail(planWorkoutID: UUID)
    /// Manual / completed session summary keyed by `WorkoutSessionRecord.id`.
    case completedSession(sessionID: UUID)
    /// Live Workout Screen kept on the Insights stack (stack affinity).
    case workoutScreen(planWorkoutID: UUID)
    /// Completion summary after hold-to-finish from an Insights-opened Screen.
    case workoutCompletion(planWorkoutID: UUID, workoutSessionID: UUID, elapsedSeconds: Int)
}
