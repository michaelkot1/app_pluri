import Foundation

/// Deterministic in-memory `CommunityClient` for previews and tests — no
/// network access, no invented remote feed beyond the seeded fixtures.
struct MockCommunityClient: CommunityClient, Sendable {
    /// Mutable fixture store (reference box so the Sendable struct can update).
    private let store: Store

    var errorToThrow: CommunityClientError? {
        get { store.errorToThrow }
        set { store.errorToThrow = newValue }
    }

    var posts: [CommunityPost] {
        get { store.posts }
        set { store.posts = newValue }
    }

    var commentsByPostId: [UUID: [CommunityComment]] {
        get { store.commentsByPostId }
        set { store.commentsByPostId = newValue }
    }

    init(
        posts: [CommunityPost] = .communityPreviewFixtures,
        commentsByPostId: [UUID: [CommunityComment]] = [:],
        errorToThrow: CommunityClientError? = nil
    ) {
        self.store = Store(
            posts: posts,
            commentsByPostId: commentsByPostId,
            errorToThrow: errorToThrow
        )
    }

    func fetchFeed(limit: Int, cursor: CommunityFeedCursor?) async throws -> CommunityFeedPage {
        try throwIfNeeded()
        return page(from: sortedPosts(), limit: limit, cursor: cursor)
    }

    func search(
        query: String,
        types: [CommunityPostType]?,
        limit: Int,
        cursor: CommunityFeedCursor?
    ) async throws -> CommunityFeedPage {
        try throwIfNeeded()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        var filtered = sortedPosts().filter { post in
            post.title.localizedStandardContains(trimmed)
                || post.body.localizedStandardContains(trimmed)
        }
        if let types, !types.isEmpty {
            filtered = filtered.filter { types.contains($0.postType) }
        }
        return page(from: filtered, limit: limit, cursor: cursor)
    }

    func createPost(_ draft: CreateCommunityPostDraft) async throws -> CommunityPost {
        try throwIfNeeded()
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard CommunityTextRules.isValidPost(title: title, body: body) else {
            throw CommunityClientError.invalidRequest(
                "Add a title and at least three words in the body to post."
            )
        }

        if draft.postType == .shareWorkout, draft.workoutSnapshot == nil {
            throw CommunityClientError.invalidRequest("Share Workout needs a workout snapshot.")
        }

        let postId = UUID()
        let poll: CommunityPoll?
        if let draftPoll = draft.poll {
            let options = draftPoll.options
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            poll = CommunityPoll(
                id: UUID(),
                question: draftPoll.question.trimmingCharacters(in: .whitespacesAndNewlines),
                options: options,
                voteCounts: Array(repeating: 0, count: options.count),
                viewerOptionIndex: nil
            )
        } else {
            poll = nil
        }

        let post = CommunityPost(
            id: postId,
            author: CommunityAuthor(
                id: Self.viewerAuthorID,
                displayName: "You"
            ),
            title: title,
            body: body,
            postType: draft.postType,
            imageURL: nil,
            workoutSnapshot: draft.workoutSnapshot,
            poll: poll,
            likeCount: 0,
            commentCount: 0,
            isLikedByViewer: false,
            isSavedByViewer: false,
            createdAt: .now
        )
        store.posts.insert(post, at: 0)
        return post
    }

    func likePost(postId: UUID) async throws {
        try throwIfNeeded()
        updatePost(id: postId) { post in
            guard !post.isLikedByViewer else { return post }
            return mutatingCopy(post, likeCount: post.likeCount + 1, isLikedByViewer: true)
        }
    }

    func unlikePost(postId: UUID) async throws {
        try throwIfNeeded()
        updatePost(id: postId) { post in
            guard post.isLikedByViewer else { return post }
            return mutatingCopy(
                post,
                likeCount: max(0, post.likeCount - 1),
                isLikedByViewer: false
            )
        }
    }

    func addComment(postId: UUID, body: String) async throws -> CommunityComment {
        try throwIfNeeded()
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CommunityClientError.invalidRequest("Write a comment before posting.")
        }
        guard store.posts.contains(where: { $0.id == postId }) else {
            throw CommunityClientError.notFound
        }
        let comment = CommunityComment(
            id: UUID(),
            postId: postId,
            author: CommunityAuthor(
                id: Self.viewerAuthorID,
                displayName: "You"
            ),
            body: trimmed,
            createdAt: .now
        )
        var list = store.commentsByPostId[postId] ?? []
        list.append(comment)
        store.commentsByPostId[postId] = list
        updatePost(id: postId) { post in
            mutatingCopy(post, commentCount: post.commentCount + 1)
        }
        return comment
    }

    func fetchComments(postId: UUID, limit: Int) async throws -> [CommunityComment] {
        try throwIfNeeded()
        let comments = store.commentsByPostId[postId] ?? []
        return Array(comments.prefix(max(limit, 1)))
    }

    func votePoll(pollId: UUID, optionIndex: Int) async throws {
        try throwIfNeeded()
        guard optionIndex >= 0 else {
            throw CommunityClientError.invalidRequest("Pick a valid poll option.")
        }
        for (index, post) in store.posts.enumerated() {
            guard var poll = post.poll, poll.id == pollId else { continue }
            guard optionIndex < poll.options.count else {
                throw CommunityClientError.invalidRequest("Pick a valid poll option.")
            }
            var counts = poll.voteCounts
            if counts.count != poll.options.count {
                counts = Array(repeating: 0, count: poll.options.count)
            }
            if let previous = poll.viewerOptionIndex, previous >= 0, previous < counts.count {
                counts[previous] = max(0, counts[previous] - 1)
            }
            counts[optionIndex] += 1
            poll = CommunityPoll(
                id: poll.id,
                question: poll.question,
                options: poll.options,
                voteCounts: counts,
                viewerOptionIndex: optionIndex
            )
            store.posts[index] = mutatingCopy(post, poll: poll)
            return
        }
        throw CommunityClientError.notFound
    }

    func savePost(postId: UUID) async throws {
        try throwIfNeeded()
        updatePost(id: postId) { mutatingCopy($0, isSavedByViewer: true) }
    }

    func unsavePost(postId: UUID) async throws {
        try throwIfNeeded()
        updatePost(id: postId) { mutatingCopy($0, isSavedByViewer: false) }
    }

    func fetchSaved(limit: Int, cursor: CommunityFeedCursor?) async throws -> CommunityFeedPage {
        try throwIfNeeded()
        let saved = sortedPosts().filter(\.isSavedByViewer)
        return page(from: saved, limit: limit, cursor: cursor)
    }

    func report(postId: UUID, reason: String) async throws {
        try throwIfNeeded()
        _ = reason
        // Soft-hide for reporter: remove from local fixture feed.
        store.posts.removeAll { $0.id == postId }
    }

    func hide(postId: UUID) async throws {
        try throwIfNeeded()
        store.posts.removeAll { $0.id == postId }
    }

    func block(authorId: UUID) async throws {
        try throwIfNeeded()
        store.posts.removeAll { $0.author.id == authorId }
    }

    func fetchRepliesToMyPosts(limit: Int) async throws -> [CommunityReplyNotification] {
        try throwIfNeeded()
        let clamped = min(max(limit, 1), 50)
        let myPostIds = Set(
            store.posts
                .filter { $0.author.id == Self.viewerAuthorID }
                .map(\.id)
        )
        let titlesById = Dictionary(
            uniqueKeysWithValues: store.posts.map { ($0.id, $0.title) }
        )

        var replies: [CommunityReplyNotification] = []
        for (postId, comments) in store.commentsByPostId {
            guard myPostIds.contains(postId) else { continue }
            for comment in comments where comment.author.id != Self.viewerAuthorID {
                replies.append(
                    CommunityReplyNotification(
                        comment: comment,
                        postTitle: titlesById[postId] ?? "Your post"
                    )
                )
            }
        }

        replies.sort {
            if $0.comment.createdAt == $1.comment.createdAt {
                return $0.comment.id.uuidString > $1.comment.id.uuidString
            }
            return $0.comment.createdAt > $1.comment.createdAt
        }
        return Array(replies.prefix(clamped))
    }

    // MARK: - Helpers

    static let viewerAuthorID = UUID(uuidString: "00000000-0000-4000-8000-000000000099")!
    private func throwIfNeeded() throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }

    private func sortedPosts() -> [CommunityPost] {
        store.posts.sorted {
            if $0.createdAt == $1.createdAt {
                return $0.id.uuidString > $1.id.uuidString
            }
            return $0.createdAt > $1.createdAt
        }
    }

    private func page(
        from posts: [CommunityPost],
        limit: Int,
        cursor: CommunityFeedCursor?
    ) -> CommunityFeedPage {
        let clamped = min(max(limit, 1), 50)
        let sliced: [CommunityPost]
        if let cursor {
            sliced = posts.filter { post in
                if post.createdAt < cursor.createdAt { return true }
                if post.createdAt > cursor.createdAt { return false }
                return post.id.uuidString < cursor.id.uuidString
            }
        } else {
            sliced = posts
        }
        let pagePosts = Array(sliced.prefix(clamped))
        let next: CommunityFeedCursor?
        if pagePosts.count == clamped, let last = pagePosts.last {
            next = CommunityFeedCursor(createdAt: last.createdAt, id: last.id)
        } else {
            next = nil
        }
        return CommunityFeedPage(posts: pagePosts, nextCursor: next)
    }

    private func updatePost(id: UUID, transform: (CommunityPost) -> CommunityPost) {
        guard let index = store.posts.firstIndex(where: { $0.id == id }) else { return }
        store.posts[index] = transform(store.posts[index])
    }

    private func mutatingCopy(
        _ post: CommunityPost,
        likeCount: Int? = nil,
        commentCount: Int? = nil,
        isLikedByViewer: Bool? = nil,
        isSavedByViewer: Bool? = nil,
        poll: CommunityPoll? = nil
    ) -> CommunityPost {
        CommunityPost(
            id: post.id,
            author: post.author,
            title: post.title,
            body: post.body,
            postType: post.postType,
            imageURL: post.imageURL,
            workoutSnapshot: post.workoutSnapshot,
            poll: poll ?? post.poll,
            likeCount: likeCount ?? post.likeCount,
            commentCount: commentCount ?? post.commentCount,
            isLikedByViewer: isLikedByViewer ?? post.isLikedByViewer,
            isSavedByViewer: isSavedByViewer ?? post.isSavedByViewer,
            createdAt: post.createdAt
        )
    }
}

extension MockCommunityClient {
    final class Store: @unchecked Sendable {
        var posts: [CommunityPost]
        var commentsByPostId: [UUID: [CommunityComment]]
        var errorToThrow: CommunityClientError?

        init(
            posts: [CommunityPost],
            commentsByPostId: [UUID: [CommunityComment]],
            errorToThrow: CommunityClientError?
        ) {
            self.posts = posts
            self.commentsByPostId = commentsByPostId
            self.errorToThrow = errorToThrow
        }
    }
}

extension [CommunityPost] {
    /// Small deterministic fixture set for Community previews / unit tests.
    static var communityPreviewFixtures: [CommunityPost] {
        let authorA = CommunityAuthor(
            id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            displayName: "Alex"
        )
        let authorB = CommunityAuthor(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
            displayName: "Jordan"
        )
        let older = Date(timeIntervalSince1970: 1_753_603_200) // 2025-07-27
        let newer = Date(timeIntervalSince1970: 1_753_689_600) // 2025-07-28

        return [
            CommunityPost(
                id: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!,
                author: authorA,
                title: "Rest day stretch tips",
                body: "Three easy hip openers that help me recover after legs.",
                postType: .general,
                imageURL: nil,
                workoutSnapshot: nil,
                poll: CommunityPoll(
                    id: UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!,
                    question: "Do you take a full rest day?",
                    options: ["Yes", "No"],
                    voteCounts: [3, 1],
                    viewerOptionIndex: nil
                ),
                likeCount: 4,
                commentCount: 1,
                isLikedByViewer: false,
                isSavedByViewer: true,
                createdAt: newer
            ),
            CommunityPost(
                id: UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!,
                author: authorB,
                title: "Favorite lifting shoes",
                body: "Looking for flat soles that stay grippy on deadlift days.",
                postType: .gear,
                imageURL: nil,
                workoutSnapshot: nil,
                poll: nil,
                likeCount: 2,
                commentCount: 0,
                isLikedByViewer: true,
                isSavedByViewer: false,
                createdAt: older
            ),
            CommunityPost(
                id: UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")!,
                author: authorA,
                title: "Push day complete",
                body: "Hit every set with one rep in reserve.",
                postType: .shareWorkout,
                imageURL: nil,
                workoutSnapshot: WorkoutSnapshot(
                    sessionId: UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")!,
                    title: "Chest & Triceps",
                    activityType: "workout",
                    durationSeconds: 3_240,
                    distanceMeters: nil,
                    setCount: 18,
                    repCount: 142
                ),
                poll: nil,
                likeCount: 8,
                commentCount: 2,
                isLikedByViewer: false,
                isSavedByViewer: false,
                createdAt: Date(timeIntervalSince1970: 1_753_516_800) // 2025-07-26
            ),
        ]
    }
}
