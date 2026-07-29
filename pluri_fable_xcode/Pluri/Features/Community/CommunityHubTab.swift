import Foundation

/// Top-level Community hub tabs (SPEC §11 / §14 #73): Feed · Discover · Saved.
enum CommunityHubTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case feed
    case discover
    case saved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feed: "Feed"
        case .discover: "Discover"
        case .saved: "Saved"
        }
    }
}
