import Foundation

/// Author attribution for feed cards — sourced only from
/// `community_author_profiles` (SPEC §14 #73). Never from full `profiles`.
struct CommunityAuthor: Sendable, Equatable, Hashable, Identifiable {
    let id: UUID
    /// Display name, or the fallback label when the author row is missing.
    let displayName: String
}

/// Optional poll attached to a post (`post_polls` + aggregated `poll_votes`).
struct CommunityPoll: Sendable, Equatable, Hashable, Identifiable {
    let id: UUID
    let question: String
    /// JSON string array locked in SPEC §14 (e.g. `["Yes","No"]`).
    let options: [String]
    /// Per-option vote totals (same length as `options`).
    let voteCounts: [Int]
    /// Viewer's selected option when signed in and voted; otherwise `nil`.
    let viewerOptionIndex: Int?
}

/// Domain post for feed / search / saved lists.
struct CommunityPost: Sendable, Equatable, Hashable, Identifiable {
    let id: UUID
    let author: CommunityAuthor
    let title: String
    let body: String
    let postType: CommunityPostType
    let imageURL: URL?
    let workoutSnapshot: WorkoutSnapshot?
    let poll: CommunityPoll?
    let likeCount: Int
    let commentCount: Int
    let isLikedByViewer: Bool
    let isSavedByViewer: Bool
    let createdAt: Date
}

/// Comment on a post (`post_comments` + author attribution).
struct CommunityComment: Sendable, Equatable, Hashable, Identifiable {
    let id: UUID
    let postId: UUID
    let author: CommunityAuthor
    let body: String
    let createdAt: Date
}

/// Cursor for chronological feed pagination (`created_at DESC`, then `id DESC`).
struct CommunityFeedCursor: Sendable, Equatable, Hashable {
    let createdAt: Date
    let id: UUID
}

/// One page of chronological posts plus an optional next cursor.
struct CommunityFeedPage: Sendable, Equatable {
    let posts: [CommunityPost]
    let nextCursor: CommunityFeedCursor?

    static let empty = CommunityFeedPage(posts: [], nextCursor: nil)
}

/// Optional image bytes for create-post upload (`post-images` bucket).
struct CommunityPostImageUpload: Sendable, Equatable {
    let data: Data
    /// MIME type — jpeg / png / heic only (SPEC §14 #72c).
    let contentType: String
    /// File extension matching the MIME (jpg / png / heic).
    let fileExtension: String
}

/// Optional poll draft for create-post. Options are a JSON string array.
struct CreateCommunityPollDraft: Sendable, Equatable {
    let question: String
    let options: [String]
}

/// In-app Notifications row: someone else replied to one of the viewer's posts
/// (M8-12 / SPEC §5.3 / §14 #72g). No push in M8.
struct CommunityReplyNotification: Sendable, Equatable, Hashable, Identifiable {
    var id: UUID { comment.id }
    let comment: CommunityComment
    /// Title of the post that received the reply.
    let postTitle: String
}

/// Create-post payload for `CommunityClient.createPost`.
struct CreateCommunityPostDraft: Sendable, Equatable {
    let title: String
    let body: String
    let postType: CommunityPostType
    let workoutSnapshot: WorkoutSnapshot?
    let poll: CreateCommunityPollDraft?
    let image: CommunityPostImageUpload?

    init(
        title: String,
        body: String,
        postType: CommunityPostType,
        workoutSnapshot: WorkoutSnapshot? = nil,
        poll: CreateCommunityPollDraft? = nil,
        image: CommunityPostImageUpload? = nil
    ) {
        self.title = title
        self.body = body
        self.postType = postType
        self.workoutSnapshot = workoutSnapshot
        self.poll = poll
        self.image = image
    }
}
