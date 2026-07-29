import Foundation

/// Wire-format DTOs for Community PostgREST reads (snake_case CodingKeys).

/// Aggregate embed shape for `post_likes(count)` / `post_comments(count)`.
struct CommunityCountEmbedDTO: Decodable, Sendable, Equatable {
    let count: Int
}

/// One `poll_votes` row embedded under a poll.
struct CommunityPollVoteEmbedDTO: Decodable, Sendable, Equatable {
    let optionIndex: Int
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case optionIndex = "option_index"
        case userId = "user_id"
    }
}

/// `post_polls` row (+ optional vote embeds).
struct CommunityPollEmbedDTO: Decodable, Sendable, Equatable {
    let id: UUID
    let question: String
    /// Locked as a JSON string array (SPEC §14).
    let options: [String]
    let pollVotes: [CommunityPollVoteEmbedDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case question
        case options
        case pollVotes = "poll_votes"
    }
}

/// Author row from `community_author_profiles` (`id`, `display_name` only).
struct CommunityAuthorProfileDTO: Decodable, Sendable, Equatable {
    let id: UUID
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

/// Feed/search post row with count + poll embeds.
struct CommunityPostRowDTO: Decodable, Sendable, Equatable {
    let id: UUID
    let userId: UUID
    let title: String
    let body: String
    let postType: String
    let imagePath: String?
    let workoutSnapshot: WorkoutSnapshot?
    let createdAt: String
    let postLikes: [CommunityCountEmbedDTO]?
    let postComments: [CommunityCountEmbedDTO]?
    let postPolls: [CommunityPollEmbedDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case body
        case postType = "post_type"
        case imagePath = "image_path"
        case workoutSnapshot = "workout_snapshot"
        case createdAt = "created_at"
        case postLikes = "post_likes"
        case postComments = "post_comments"
        case postPolls = "post_polls"
    }

    /// Columns for chronological feed / search selects.
    static let selectColumns =
        "id, user_id, title, body, post_type, image_path, workout_snapshot, created_at, post_likes(count), post_comments(count), post_polls(id, question, options, poll_votes(option_index, user_id))"
}

/// `saved_posts` join row used by `fetchSaved`.
struct CommunitySavedPostJoinDTO: Decodable, Sendable, Equatable {
    let createdAt: String
    let posts: CommunityPostRowDTO

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case posts
    }

    static let selectColumns =
        "created_at, posts(\(CommunityPostRowDTO.selectColumns))"
}

/// `post_comments` row for comment list / create response.
struct CommunityCommentRowDTO: Decodable, Sendable, Equatable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let body: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case body
        case createdAt = "created_at"
    }

    static let selectColumns = "id, post_id, user_id, body, created_at"
}

/// Insert payload for `public.posts`.
struct CommunityPostInsertRow: Encodable, Sendable, Equatable {
    let id: UUID
    let userId: UUID
    let title: String
    let body: String
    let postType: String
    let imagePath: String?
    let workoutSnapshot: WorkoutSnapshot?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case body
        case postType = "post_type"
        case imagePath = "image_path"
        case workoutSnapshot = "workout_snapshot"
    }
}

/// Patch `posts.image_path` after a successful Storage upload.
struct CommunityPostImagePathUpdate: Encodable, Sendable, Equatable {
    let imagePath: String

    enum CodingKeys: String, CodingKey {
        case imagePath = "image_path"
    }
}

/// Insert payload for `public.post_polls`.
struct CommunityPollInsertRow: Encodable, Sendable, Equatable {
    let postId: UUID
    let question: String
    let options: [String]

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case question
        case options
    }
}

/// Insert payload for `public.post_likes`.
struct CommunityLikeInsertRow: Encodable, Sendable, Equatable {
    let userId: UUID
    let postId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case postId = "post_id"
    }
}

/// Insert payload for `public.post_comments`.
struct CommunityCommentInsertRow: Encodable, Sendable, Equatable {
    let userId: UUID
    let postId: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case postId = "post_id"
        case body
    }
}

/// Insert payload for `public.poll_votes`.
struct CommunityPollVoteInsertRow: Encodable, Sendable, Equatable {
    let userId: UUID
    let pollId: UUID
    let optionIndex: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case pollId = "poll_id"
        case optionIndex = "option_index"
    }
}

/// Insert payload for `public.saved_posts`.
struct CommunitySavedPostInsertRow: Encodable, Sendable, Equatable {
    let userId: UUID
    let postId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case postId = "post_id"
    }
}

/// Insert payload for `public.post_reports` (trigger bumps `reported` / `report_count`).
struct CommunityReportInsertRow: Encodable, Sendable, Equatable {
    let reporterId: UUID
    let postId: UUID
    let reason: String

    enum CodingKeys: String, CodingKey {
        case reporterId = "reporter_id"
        case postId = "post_id"
        case reason
    }
}

/// Insert payload for `public.post_hides`.
struct CommunityHideInsertRow: Encodable, Sendable, Equatable {
    let userId: UUID
    let postId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case postId = "post_id"
    }
}

/// Insert payload for `public.user_blocks`.
struct CommunityBlockInsertRow: Encodable, Sendable, Equatable {
    let blockerId: UUID
    let blockedId: UUID

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

/// Thin id-only row for viewer like / saved lookups.
struct CommunityPostIdRowDTO: Decodable, Sendable, Equatable {
    let postId: UUID

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
    }
}
