import Foundation

/// Preset report reasons for UGC moderation (M8-11 / SPEC §14 #75).
enum CommunityReportReason: String, CaseIterable, Identifiable, Sendable {
    case spam
    case harassment
    case inappropriate
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spam: "Spam or misleading"
        case .harassment: "Harassment or bullying"
        case .inappropriate: "Inappropriate content"
        case .other: "Something else"
        }
    }

    /// Persisted reason string sent to `CommunityClient.report`.
    var persistenceValue: String { rawValue }
}
