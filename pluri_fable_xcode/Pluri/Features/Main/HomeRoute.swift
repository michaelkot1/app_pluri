import Foundation

/// Typed destinations pushable from the Home tab's `NavigationStack` (M3-06).
/// Calendar, Notifications, Workout Detail, and Outdoor Run are honest stubs
/// until their milestones (M3-13 / M3-15 / M4) land.
enum HomeRoute: Hashable, Sendable {
    case profile
    case notifications
    case calendarStub
    case workoutDetail(sessionID: UUID)
    case outdoorRunStub
}
