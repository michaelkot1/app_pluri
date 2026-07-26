import Foundation

/// Typed destinations pushable from the Home tab's `NavigationStack` (M3-06).
/// Calendar is the real M3-13 page and Notifications the real M3-15 page;
/// Workout Detail is live (M4-05); Workout Screen is a thin stub until M4-07;
/// Outdoor Run stays an honest stub until M4.
enum HomeRoute: Hashable, Sendable {
    case profile
    case notifications
    case calendar
    case workoutDetail(sessionID: UUID)
    case workoutScreen(sessionID: UUID)
    /// Completion stub until M4-12 (name + elapsed only).
    case workoutCompletion(planWorkoutID: UUID, workoutSessionID: UUID, elapsedSeconds: Int)
    case outdoorRunStub
}
