import Foundation
import SwiftData

/// Cached full-recipe candidate pool for the day-suggestions engine (M7-08).
///
/// Engine needs ingredients for allergy + favorites similarity, so filter
/// summaries alone are insufficient — this stores lookup/search-complete
/// recipes. One row per user; refreshed opportunistically when online.
@Model
final class RecipeCandidatePoolRecord {
    #Unique<RecipeCandidatePoolRecord>([\.userId])

    var id: UUID = UUID()
    var userId: UUID = UUID()
    /// JSON-encoded `[MealDBRecipe]`.
    var payloadJSON: Data = Data()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        userId: UUID,
        payloadJSON: Data,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.payloadJSON = payloadJSON
        self.updatedAt = updatedAt
    }
}
