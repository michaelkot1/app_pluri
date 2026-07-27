import Foundation

/// Top-level Recipe tabs (SPEC §12): Day suggestions and Explore.
enum RecipePrimaryTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case day
    case explore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "Day"
        case .explore: "Explore"
        }
    }
}
