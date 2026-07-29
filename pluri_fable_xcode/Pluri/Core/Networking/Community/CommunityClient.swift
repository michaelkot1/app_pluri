import Foundation

/// Community networking surface for feed / create / engagement / moderation
/// (M8-04). Abstracted behind a protocol so a live Supabase-backed
/// implementation and a deterministic mock (previews/tests) share call sites
/// — see PLAN §1.2 / §3 and SPEC §14 #72 / #73.
///
/// Offline: throw typed `CommunityClientError` — never invent feed content (#72d).
protocol CommunityClient: Sendable {
    /// Chronological feed (`created_at DESC` only — SPEC §14 #72b).
    func fetchFeed(limit: Int, cursor: CommunityFeedCursor?) async throws -> CommunityFeedPage

    /// Title/body search with optional post-type filter.
    func search(
        query: String,
        types: [CommunityPostType]?,
        limit: Int,
        cursor: CommunityFeedCursor?
    ) async throws -> CommunityFeedPage

    /// Creates a post (optional poll + optional image upload under owner prefix).
    func createPost(_ draft: CreateCommunityPostDraft) async throws -> CommunityPost

    func likePost(postId: UUID) async throws
    func unlikePost(postId: UUID) async throws

    func addComment(postId: UUID, body: String) async throws -> CommunityComment
    func fetchComments(postId: UUID, limit: Int) async throws -> [CommunityComment]

    func votePoll(pollId: UUID, optionIndex: Int) async throws

    func savePost(postId: UUID) async throws
    func unsavePost(postId: UUID) async throws
    func fetchSaved(limit: Int, cursor: CommunityFeedCursor?) async throws -> CommunityFeedPage

    /// Inserts `post_reports` only — trigger bumps `reported` / `report_count`.
    func report(postId: UUID, reason: String) async throws
    func hide(postId: UUID) async throws
    func block(authorId: UUID) async throws

    /// Recent replies on the viewer's posts (excludes self-comments) for
    /// Notifications Community rows (M8-12 / SPEC §14 #72g / #75).
    func fetchRepliesToMyPosts(limit: Int) async throws -> [CommunityReplyNotification]
}
