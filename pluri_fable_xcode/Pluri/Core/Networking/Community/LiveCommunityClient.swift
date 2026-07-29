import Foundation
import Supabase
import os.log

/// Live `CommunityClient` over Supabase PostgREST + Storage (`post-images`).
/// Reads authors from `community_author_profiles` only — never full `profiles`
/// (SPEC §14 #73). Counts come from `post_likes` / `post_comments` embeds.
struct LiveCommunityClient: CommunityClient {
    static let postImagesBucket = "post-images"
    static let maxImageBytes = 5 * 1024 * 1024
    static let fallbackAuthorDisplayName = "Pluri member"
    static let allowedImageContentTypes: Set<String> = [
        "image/jpeg",
        "image/png",
        "image/heic",
    ]

    private let client: SupabaseClient
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "CommunityClient")

    init(client: SupabaseClient) {
        self.client = client
    }

    @MainActor
    init(supabaseService: SupabaseService) {
        self.init(client: supabaseService.client)
    }

    // MARK: - Feed / search

    func fetchFeed(limit: Int, cursor: CommunityFeedCursor?) async throws -> CommunityFeedPage {
        let clamped = clampLimit(limit)
        do {
            var query = client
                .from("posts")
                .select(CommunityPostRowDTO.selectColumns)

            if let cursor {
                query = query.or(cursorFilter(cursor))
            }

            let rows: [CommunityPostRowDTO] = try await query
                .order("created_at", ascending: false)
                .order("id", ascending: false)
                .limit(clamped)
                .execute()
                .value
            return try await hydratePage(rows: rows, limit: clamped)
        } catch let error as CommunityClientError {
            throw error
        } catch {
            throw mapTransport(error, context: "feed")
        }
    }

    func search(
        query: String,
        types: [CommunityPostType]?,
        limit: Int,
        cursor: CommunityFeedCursor?
    ) async throws -> CommunityFeedPage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        let clamped = clampLimit(limit)
        let pattern = "%\(escapeILike(trimmed))%"

        do {
            var request = client
                .from("posts")
                .select(CommunityPostRowDTO.selectColumns)
                .or("title.ilike.\"\(pattern)\",body.ilike.\"\(pattern)\"")

            if let types, !types.isEmpty {
                request = request.in("post_type", values: types.map(\.rawValue))
            }
            if let cursor {
                request = request.or(cursorFilter(cursor))
            }

            let rows: [CommunityPostRowDTO] = try await request
                .order("created_at", ascending: false)
                .order("id", ascending: false)
                .limit(clamped)
                .execute()
                .value
            return try await hydratePage(rows: rows, limit: clamped)
        } catch let error as CommunityClientError {
            throw error
        } catch {
            throw mapTransport(error, context: "search")
        }
    }

    // MARK: - Create

    func createPost(_ draft: CreateCommunityPostDraft) async throws -> CommunityPost {
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

        if let poll = draft.poll {
            let question = poll.question.trimmingCharacters(in: .whitespacesAndNewlines)
            let options = poll.options
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !question.isEmpty, options.count >= 2 else {
                throw CommunityClientError.invalidRequest("Polls need a question and at least two options.")
            }
        }

        if let image = draft.image {
            try validateImage(image)
        }

        let userId = try await requireUserId()
        let postId = UUID()

        do {
            let insert = CommunityPostInsertRow(
                id: postId,
                userId: userId,
                title: title,
                body: body,
                postType: draft.postType.rawValue,
                imagePath: nil,
                workoutSnapshot: draft.workoutSnapshot
            )

            try await client
                .from("posts")
                .insert(insert)
                .execute()

            if let image = draft.image {
                let path = "\(userId.uuidString.lowercased())/\(postId.uuidString.lowercased()).\(image.fileExtension.lowercased())"
                try await client.storage
                    .from(Self.postImagesBucket)
                    .upload(
                        path,
                        data: image.data,
                        options: FileOptions(contentType: image.contentType, upsert: true)
                    )
                try await client
                    .from("posts")
                    .update(CommunityPostImagePathUpdate(imagePath: path))
                    .eq("id", value: postId)
                    .execute()
            }

            if let poll = draft.poll {
                let question = poll.question.trimmingCharacters(in: .whitespacesAndNewlines)
                let options = poll.options
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                try await client
                    .from("post_polls")
                    .insert(
                        CommunityPollInsertRow(
                            postId: postId,
                            question: question,
                            options: options
                        )
                    )
                    .execute()
            }

            let rows: [CommunityPostRowDTO] = try await client
                .from("posts")
                .select(CommunityPostRowDTO.selectColumns)
                .eq("id", value: postId)
                .limit(1)
                .execute()
                .value

            guard let row = rows.first else {
                throw CommunityClientError.invalidResponse
            }
            let page = try await hydratePage(rows: [row], limit: 1)
            guard let post = page.posts.first else {
                throw CommunityClientError.invalidResponse
            }
            return post
        } catch let error as CommunityClientError {
            throw error
        } catch {
            throw mapTransport(error, context: "createPost")
        }
    }

    // MARK: - Likes / comments / polls

    func likePost(postId: UUID) async throws {
        let userId = try await requireUserId()
        do {
            try await client
                .from("post_likes")
                .upsert(
                    CommunityLikeInsertRow(userId: userId, postId: postId),
                    onConflict: "user_id,post_id"
                )
                .execute()
        } catch {
            throw mapTransport(error, context: "like")
        }
    }

    func unlikePost(postId: UUID) async throws {
        let userId = try await requireUserId()
        do {
            try await client
                .from("post_likes")
                .delete()
                .eq("user_id", value: userId)
                .eq("post_id", value: postId)
                .execute()
        } catch {
            throw mapTransport(error, context: "unlike")
        }
    }

    func addComment(postId: UUID, body: String) async throws -> CommunityComment {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CommunityClientError.invalidRequest("Write a comment before posting.")
        }
        let userId = try await requireUserId()
        do {
            let rows: [CommunityCommentRowDTO] = try await client
                .from("post_comments")
                .insert(
                    CommunityCommentInsertRow(userId: userId, postId: postId, body: trimmed),
                    returning: .representation
                )
                .select(CommunityCommentRowDTO.selectColumns)
                .execute()
                .value

            guard let row = rows.first else {
                throw CommunityClientError.invalidResponse
            }
            let authors = try await fetchAuthors(ids: [row.userId])
            return mapComment(row, authors: authors)
        } catch let error as CommunityClientError {
            throw error
        } catch {
            throw mapTransport(error, context: "addComment")
        }
    }

    func fetchComments(postId: UUID, limit: Int) async throws -> [CommunityComment] {
        let clamped = clampLimit(limit)
        do {
            let rows: [CommunityCommentRowDTO] = try await client
                .from("post_comments")
                .select(CommunityCommentRowDTO.selectColumns)
                .eq("post_id", value: postId)
                .order("created_at", ascending: true)
                .limit(clamped)
                .execute()
                .value

            let authors = try await fetchAuthors(ids: rows.map(\.userId))
            return rows.map { mapComment($0, authors: authors) }
        } catch let error as CommunityClientError {
            throw error
        } catch {
            throw mapTransport(error, context: "fetchComments")
        }
    }

    func votePoll(pollId: UUID, optionIndex: Int) async throws {
        guard optionIndex >= 0 else {
            throw CommunityClientError.invalidRequest("Pick a valid poll option.")
        }
        let userId = try await requireUserId()
        do {
            try await client
                .from("poll_votes")
                .upsert(
                    CommunityPollVoteInsertRow(
                        userId: userId,
                        pollId: pollId,
                        optionIndex: optionIndex
                    ),
                    onConflict: "user_id,poll_id"
                )
                .execute()
        } catch {
            throw mapTransport(error, context: "votePoll")
        }
    }

    // MARK: - Saved

    func savePost(postId: UUID) async throws {
        let userId = try await requireUserId()
        do {
            try await client
                .from("saved_posts")
                .upsert(
                    CommunitySavedPostInsertRow(userId: userId, postId: postId),
                    onConflict: "user_id,post_id"
                )
                .execute()
        } catch {
            throw mapTransport(error, context: "save")
        }
    }

    func unsavePost(postId: UUID) async throws {
        let userId = try await requireUserId()
        do {
            try await client
                .from("saved_posts")
                .delete()
                .eq("user_id", value: userId)
                .eq("post_id", value: postId)
                .execute()
        } catch {
            throw mapTransport(error, context: "unsave")
        }
    }

    func fetchSaved(limit: Int, cursor: CommunityFeedCursor?) async throws -> CommunityFeedPage {
        let userId = try await requireUserId()
        let clamped = clampLimit(limit)
        do {
            var query = client
                .from("saved_posts")
                .select(CommunitySavedPostJoinDTO.selectColumns)
                .eq("user_id", value: userId)

            if let cursor {
                // Saved list cursor uses saved_posts.created_at + posts.id for stability.
                let ts = Self.filterTimestamp(cursor.createdAt)
                query = query.or(
                    "created_at.lt.\(ts),and(created_at.eq.\(ts),posts.id.lt.\(cursor.id.uuidString))"
                )
            }

            let joins: [CommunitySavedPostJoinDTO] = try await query
                .order("created_at", ascending: false)
                .limit(clamped)
                .execute()
                .value
            let rows = joins.map(\.posts)
            let page = try await hydratePage(rows: rows, limit: clamped)
            // Rebuild next cursor from saved_posts timestamps when present.
            if joins.count == clamped, let last = joins.last {
                let createdAt = Self.parseTimestamp(last.createdAt)
                return CommunityFeedPage(
                    posts: page.posts,
                    nextCursor: CommunityFeedCursor(createdAt: createdAt, id: last.posts.id)
                )
            }
            return page
        } catch let error as CommunityClientError {
            throw error
        } catch {
            throw mapTransport(error, context: "fetchSaved")
        }
    }

    // MARK: - Moderation

    func report(postId: UUID, reason: String) async throws {
        let userId = try await requireUserId()
        do {
            try await client
                .from("post_reports")
                .upsert(
                    CommunityReportInsertRow(
                        reporterId: userId,
                        postId: postId,
                        reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
                    ),
                    onConflict: "reporter_id,post_id"
                )
                .execute()
        } catch {
            throw mapTransport(error, context: "report")
        }
    }

    func hide(postId: UUID) async throws {
        let userId = try await requireUserId()
        do {
            try await client
                .from("post_hides")
                .upsert(
                    CommunityHideInsertRow(userId: userId, postId: postId),
                    onConflict: "user_id,post_id"
                )
                .execute()
        } catch {
            throw mapTransport(error, context: "hide")
        }
    }

    func block(authorId: UUID) async throws {
        let userId = try await requireUserId()
        guard userId != authorId else {
            throw CommunityClientError.invalidRequest("You can't block yourself.")
        }
        do {
            try await client
                .from("user_blocks")
                .upsert(
                    CommunityBlockInsertRow(blockerId: userId, blockedId: authorId),
                    onConflict: "blocker_id,blocked_id"
                )
                .execute()
        } catch {
            throw mapTransport(error, context: "block")
        }
    }

    // MARK: - Notifications (M8-12)

    func fetchRepliesToMyPosts(limit: Int) async throws -> [CommunityReplyNotification] {
        let clamped = clampLimit(limit)
        let userId = try await requireUserId()
        do {
            struct MyPostTitleRow: Decodable {
                let id: UUID
                let title: String
            }

            let myPosts: [MyPostTitleRow] = try await client
                .from("posts")
                .select("id, title")
                .eq("user_id", value: userId)
                .execute()
                .value

            guard !myPosts.isEmpty else { return [] }

            let titlesById = Dictionary(uniqueKeysWithValues: myPosts.map { ($0.id, $0.title) })
            let postIds = myPosts.map(\.id)

            let rows: [CommunityCommentRowDTO] = try await client
                .from("post_comments")
                .select(CommunityCommentRowDTO.selectColumns)
                .in("post_id", values: postIds)
                .neq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(clamped)
                .execute()
                .value

            let authors = try await fetchAuthors(ids: rows.map(\.userId))
            return rows.map { row in
                CommunityReplyNotification(
                    comment: mapComment(row, authors: authors),
                    postTitle: titlesById[row.postId] ?? "Your post"
                )
            }
        } catch let error as CommunityClientError {
            throw error
        } catch {
            throw mapTransport(error, context: "fetchRepliesToMyPosts")
        }
    }

    // MARK: - Hydration

    private func hydratePage(rows: [CommunityPostRowDTO], limit: Int) async throws -> CommunityFeedPage {
        guard !rows.isEmpty else { return .empty }

        let authorIds = Array(Set(rows.map(\.userId)))
        let authors = try await fetchAuthors(ids: authorIds)
        let viewerId = try? await currentUserId()
        let postIds = rows.map(\.id)

        let likedIds: Set<UUID>
        let savedIds: Set<UUID>
        if let viewerId {
            likedIds = try await fetchViewerPostIds(
                table: "post_likes",
                userIdColumn: "user_id",
                userId: viewerId,
                postIds: postIds
            )
            savedIds = try await fetchViewerPostIds(
                table: "saved_posts",
                userIdColumn: "user_id",
                userId: viewerId,
                postIds: postIds
            )
        } else {
            likedIds = []
            savedIds = []
        }

        let posts = rows.compactMap { row -> CommunityPost? in
            mapPost(
                row,
                authors: authors,
                viewerId: viewerId,
                likedIds: likedIds,
                savedIds: savedIds
            )
        }

        let nextCursor: CommunityFeedCursor?
        if rows.count == limit, let last = rows.last {
            nextCursor = CommunityFeedCursor(
                createdAt: Self.parseTimestamp(last.createdAt),
                id: last.id
            )
        } else {
            nextCursor = nil
        }

        return CommunityFeedPage(posts: posts, nextCursor: nextCursor)
    }

    private func fetchAuthors(ids: [UUID]) async throws -> [UUID: CommunityAuthorProfileDTO] {
        let unique = Array(Set(ids))
        guard !unique.isEmpty else { return [:] }
        do {
            let rows: [CommunityAuthorProfileDTO] = try await client
                .from("community_author_profiles")
                .select("id, display_name")
                .in("id", values: unique)
                .execute()
                .value
            return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        } catch {
            logger.error("community_author_profiles batch failed: \(error.localizedDescription)")
            throw mapTransport(error, context: "authors")
        }
    }

    private func fetchViewerPostIds(
        table: String,
        userIdColumn: String,
        userId: UUID,
        postIds: [UUID]
    ) async throws -> Set<UUID> {
        guard !postIds.isEmpty else { return [] }
        let rows: [CommunityPostIdRowDTO] = try await client
            .from(table)
            .select("post_id")
            .eq(userIdColumn, value: userId)
            .in("post_id", values: postIds)
            .execute()
            .value
        return Set(rows.map(\.postId))
    }

    private func mapPost(
        _ row: CommunityPostRowDTO,
        authors: [UUID: CommunityAuthorProfileDTO],
        viewerId: UUID?,
        likedIds: Set<UUID>,
        savedIds: Set<UUID>
    ) -> CommunityPost? {
        guard let postType = CommunityPostType(rawValue: row.postType) else {
            logger.error("Unknown post_type \(row.postType) for post \(row.id.uuidString)")
            return nil
        }

        let authorDTO = authors[row.userId]
        let displayName = normalizedDisplayName(authorDTO?.displayName)
        let author = CommunityAuthor(id: row.userId, displayName: displayName)

        let likeCount = row.postLikes?.first?.count ?? 0
        let commentCount = row.postComments?.first?.count ?? 0
        let poll = row.postPolls?.first.map { mapPoll($0, viewerId: viewerId) }

        return CommunityPost(
            id: row.id,
            author: author,
            title: row.title,
            body: row.body,
            postType: postType,
            imageURL: publicImageURL(path: row.imagePath),
            workoutSnapshot: row.workoutSnapshot,
            poll: poll,
            likeCount: likeCount,
            commentCount: commentCount,
            isLikedByViewer: likedIds.contains(row.id),
            isSavedByViewer: savedIds.contains(row.id),
            createdAt: Self.parseTimestamp(row.createdAt)
        )
    }

    private func mapPoll(_ dto: CommunityPollEmbedDTO, viewerId: UUID?) -> CommunityPoll {
        let votes = dto.pollVotes ?? []
        var counts = Array(repeating: 0, count: dto.options.count)
        var viewerOption: Int?
        for vote in votes {
            if vote.optionIndex >= 0, vote.optionIndex < counts.count {
                counts[vote.optionIndex] += 1
            }
            if let viewerId, vote.userId == viewerId {
                viewerOption = vote.optionIndex
            }
        }
        return CommunityPoll(
            id: dto.id,
            question: dto.question,
            options: dto.options,
            voteCounts: counts,
            viewerOptionIndex: viewerOption
        )
    }

    private func mapComment(
        _ row: CommunityCommentRowDTO,
        authors: [UUID: CommunityAuthorProfileDTO]
    ) -> CommunityComment {
        let displayName = normalizedDisplayName(authors[row.userId]?.displayName)
        return CommunityComment(
            id: row.id,
            postId: row.postId,
            author: CommunityAuthor(id: row.userId, displayName: displayName),
            body: row.body,
            createdAt: Self.parseTimestamp(row.createdAt)
        )
    }

    private func publicImageURL(path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        do {
            return try client.storage
                .from(Self.postImagesBucket)
                .getPublicURL(path: path)
        } catch {
            logger.error("post-images public URL failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func normalizedDisplayName(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? Self.fallbackAuthorDisplayName : trimmed
    }

    // MARK: - Auth / validation helpers

    private func requireUserId() async throws -> UUID {
        guard let id = try await currentUserId() else {
            throw CommunityClientError.unauthorized
        }
        return id
    }

    private func currentUserId() async throws -> UUID? {
        do {
            let session = try await client.auth.session
            return session.user.id
        } catch {
            if let current = client.auth.currentSession {
                return current.user.id
            }
            return nil
        }
    }

    private func validateImage(_ image: CommunityPostImageUpload) throws {
        guard Self.allowedImageContentTypes.contains(image.contentType.lowercased()) else {
            throw CommunityClientError.invalidRequest("Images must be JPEG, PNG, or HEIC.")
        }
        let ext = image.fileExtension.lowercased()
        let allowedExts: Set<String> = ["jpg", "jpeg", "png", "heic"]
        guard allowedExts.contains(ext) else {
            throw CommunityClientError.invalidRequest("Images must be JPEG, PNG, or HEIC.")
        }
        guard image.data.count <= Self.maxImageBytes else {
            throw CommunityClientError.invalidRequest("Images must be 5 MB or smaller.")
        }
        guard !image.data.isEmpty else {
            throw CommunityClientError.invalidRequest("That image file was empty.")
        }
    }

    private func clampLimit(_ limit: Int) -> Int {
        min(max(limit, 1), 50)
    }

    private func cursorFilter(_ cursor: CommunityFeedCursor) -> String {
        let ts = Self.filterTimestamp(cursor.createdAt)
        let id = cursor.id.uuidString
        return "created_at.lt.\(ts),and(created_at.eq.\(ts),id.lt.\(id))"
    }

    /// ISO-8601 timestamptz for PostgREST filter strings (avoids Date.rawValue ambiguity).
    static func filterTimestamp(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

    private func escapeILike(_ value: String) -> String {
        value
            .replacing("%", with: "\\%")
            .replacing("_", with: "\\_")
            .replacing(",", with: " ")
    }

    private func mapTransport(_ error: Error, context: String) -> CommunityClientError {
        let message = error.localizedDescription
        logger.error("Community \(context) failed: \(message)")
        let lower = message.lowercased()
        if lower.localizedStandardContains("network")
            || lower.localizedStandardContains("offline")
            || lower.localizedStandardContains("internet")
            || lower.localizedStandardContains("timed out")
            || lower.localizedStandardContains("could not connect") {
            return .transport(CommunityClientError.defaultOfflineMessage)
        }
        return .transport(CommunityClientError.defaultOfflineMessage)
    }

    static func parseTimestamp(_ value: String) -> Date {
        if let date = try? Date(value, strategy: .iso8601) {
            return date
        }
        // Fractional-second timestamptz fallback used elsewhere in the app.
        let withFractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        if let date = try? Date(value, strategy: withFractional) {
            return date
        }
        return .now
    }
}
