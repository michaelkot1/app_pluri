import Foundation

/// Opportunistic offline-first sync for workout sessions / set logs (M4-03)
/// and recipe favorites (M7-07).
///
/// Never blocks local SwiftData saves. Callers enqueue a session / favorite id
/// after a local mutation; the engine flushes pending rows when online (or when
/// `flushIfNeeded` is invoked). Completed sessions with a `planWorkoutId`
/// also push `plan_workouts.status = completed` (SPEC §14 #52).
@MainActor
protocol SyncEngine: AnyObject {
    /// Records interest in flushing `sessionId` and attempts an opportunistic flush.
    func enqueueSession(id: UUID)

    /// Records interest in flushing a `RecipeFavoriteRecord` and attempts flush.
    func enqueueFavorite(id: UUID)

    /// Uploads all locally pending sessions / set logs / favorites when online.
    func flushIfNeeded() async
}
