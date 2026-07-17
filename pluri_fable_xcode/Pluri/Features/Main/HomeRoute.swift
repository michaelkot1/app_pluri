import Foundation

/// Typed destinations pushable from the Home tab's `NavigationStack` (M3-06).
/// Calendar is the real M3-13 page and Notifications the real M3-15 page;
/// Outdoor Run stays an honest stub until M4.
enum HomeRoute: Hashable, Sendable {
    case profile
    case notifications
    case calendar
    case workoutDetail(sessionID: UUID)
    case outdoorRunStub
}
