import Foundation

/// Fetches profile + active plan tree for entitled returning users (M2-15).
@MainActor
protocol RemotePlanRestoreServicing: AnyObject {
    func restore(userID: UUID) async throws -> RestoredUserState?
}
