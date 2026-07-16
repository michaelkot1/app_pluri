import Foundation

/// In-memory restore stand-in for previews and unit tests (M2-15).
@MainActor
@Observable
final class MockRemotePlanRestoreService: RemotePlanRestoreServicing {
    var result: RestoredUserState?
    var nextError: PluriSyncError?
    private(set) var restoreCount = 0

    func restore(userID: UUID) async throws -> RestoredUserState? {
        _ = userID
        restoreCount += 1
        if let nextError {
            let error = nextError
            self.nextError = nil
            throw error
        }
        return result
    }
}
