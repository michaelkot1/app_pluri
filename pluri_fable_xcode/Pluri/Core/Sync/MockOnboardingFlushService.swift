import Foundation

/// In-memory flush stand-in for previews and unit tests (M2-14).
@MainActor
@Observable
final class MockOnboardingFlushService: OnboardingFlushServicing {
    private(set) var flushCount = 0
    private(set) var retryCount = 0
    private(set) var lastUserID: UUID?
    private(set) var lastPlanID: UUID?
    var nextError: PluriSyncError?
    var nextRetryError: PluriSyncError?
    /// When `true`, `retryPendingCheckpointIfNeeded` reports a successful checkpoint write.
    var retryReturnsFlushed = false
    var shouldSucceedAfterFailures = 0

    func flush(userID: UUID, answers: OnboardingAnswers, plan: GeneratedPlan) async throws {
        _ = try OnboardingSyncMapper.profileRow(userID: userID, answers: answers)
        _ = OnboardingSyncMapper.planTree(userID: userID, plan: plan)

        if shouldSucceedAfterFailures > 0 {
            shouldSucceedAfterFailures -= 1
            throw PluriSyncError.flushFailed("Transient mock failure")
        }
        if let nextError {
            let error = nextError
            self.nextError = nil
            throw error
        }
        flushCount += 1
        lastUserID = userID
        lastPlanID = plan.id
        FlushCheckpointStore.clear()
        OnboardingCompletionHintStore.markCompleted(userID: userID)
    }

    @discardableResult
    func retryPendingCheckpointIfNeeded() async throws -> Bool {
        retryCount += 1
        if let nextRetryError {
            let error = nextRetryError
            self.nextRetryError = nil
            throw error
        }
        if retryReturnsFlushed {
            if let lastUserID {
                OnboardingCompletionHintStore.markCompleted(userID: lastUserID)
            }
            return true
        }
        return false
    }
}
