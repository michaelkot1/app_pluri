import Foundation
import UserNotifications

/// Test/preview stand-in for the system notification center (M3-15): records
/// authorization requests and scheduled/removed reminders, and lets tests
/// script the authorization status and grant/deny outcomes.
@MainActor
final class MockUserNotificationCenterClient: UserNotificationCenterClient {
    /// Scripted authorization status; `requestAuthorization()` moves it to
    /// `.authorized` / `.denied` per `grantsAuthorization`.
    var currentStatus: UNAuthorizationStatus = .notDetermined

    /// Outcome of the next `requestAuthorization()` call.
    var grantsAuthorization = true

    /// When set, `add(_:)` throws this error.
    var addError: (any Error)?

    private(set) var requestAuthorizationCount = 0
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [String] = []
    /// Seedable pending queue so tests can plant leftovers before reconcile.
    var pendingRequests: [UNNotificationRequest] = []

    // Nonisolated so the type can be a default argument of test helpers,
    // whose default expressions are evaluated outside the main actor.
    nonisolated init() {}

    func authorizationStatus() async -> UNAuthorizationStatus {
        currentStatus
    }

    func requestAuthorization() async throws -> Bool {
        requestAuthorizationCount += 1
        currentStatus = grantsAuthorization ? .authorized : .denied
        return grantsAuthorization
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }

    func add(_ request: UNNotificationRequest) async throws {
        if let addError { throw addError }
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
        addedRequests.append(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
        removedIdentifiers.append(contentsOf: identifiers)
    }
}
