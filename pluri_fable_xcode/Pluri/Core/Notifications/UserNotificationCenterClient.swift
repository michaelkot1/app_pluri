import UserNotifications

/// Thin seam over `UNUserNotificationCenter` (M3-15) so the workout reminder
/// service can be unit-tested without touching the real notification system
/// (whose permission prompts and pending queue aren't scriptable in tests).
@MainActor
protocol UserNotificationCenterClient: AnyObject {
    /// The current system notification authorization status.
    func authorizationStatus() async -> UNAuthorizationStatus

    /// Requests alert + sound permission from the system; returns whether it
    /// was granted. Only ever called after the user's explicit opt-in
    /// (SPEC §14 #48).
    func requestAuthorization() async throws -> Bool

    /// All notification requests currently pending delivery.
    func pendingNotificationRequests() async -> [UNNotificationRequest]

    /// Schedules a notification request.
    func add(_ request: UNNotificationRequest) async throws

    /// Cancels pending requests by identifier.
    func removePendingRequests(withIdentifiers identifiers: [String])
}
