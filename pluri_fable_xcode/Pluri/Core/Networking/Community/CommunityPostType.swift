import Foundation

/// Community post type enum matching `posts.post_type` CHECK
/// (SPEC §11 / §14 #72 / PLAN §1.3).
enum CommunityPostType: String, Codable, Sendable, Equatable, CaseIterable, Hashable {
    case general
    case gear
    case recipe
    case shareWorkout = "share_workout"
}
