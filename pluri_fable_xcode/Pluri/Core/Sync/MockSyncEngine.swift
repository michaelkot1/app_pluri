import Foundation

/// Preview / test SyncEngine (M4-03): records enqueue / flush calls and can
/// fail the next flush. Does not touch SwiftData.
@MainActor
@Observable
final class MockSyncEngine: SyncEngine {
    private(set) var enqueueCalls: [UUID] = []
    private(set) var flushCallCount = 0
    /// When false, `flushIfNeeded` returns without counting as a successful flush.
    var isOnline = true
    /// Thrown by the next `flushIfNeeded`, then cleared.
    var nextError: PluriSyncError?
    /// When true (default), `enqueueSession` also awaits a flush Task.
    var flushOnEnqueue = true

    func enqueueSession(id: UUID) {
        enqueueCalls.append(id)
        guard flushOnEnqueue else { return }
        Task { await flushIfNeeded() }
    }

    func flushIfNeeded() async {
        guard isOnline else { return }
        flushCallCount += 1
        if let nextError {
            self.nextError = nil
            // Swallow — production SyncEngine logs and leaves needsSync set;
            // PlanStore never awaits this path for completion (SPEC §14 #52).
            _ = nextError
        }
    }
}

/// No-op SyncEngine for previews that don't exercise sync.
@MainActor
final class NoopSyncEngine: SyncEngine {
    func enqueueSession(id: UUID) {}
    func flushIfNeeded() async {}
}
