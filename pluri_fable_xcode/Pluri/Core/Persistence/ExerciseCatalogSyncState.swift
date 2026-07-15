import Foundation
import SwiftData

/// Tracks when the exercise catalog was last successfully refreshed from
/// WorkoutX. A single instance exists in the store; `ExerciseCatalogStore`
/// creates it on first refresh.
@Model
final class ExerciseCatalogSyncState {
    var lastSyncedAt: Date?

    init(lastSyncedAt: Date? = nil) {
        self.lastSyncedAt = lastSyncedAt
    }
}
