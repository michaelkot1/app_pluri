import Foundation
import Testing
@testable import Pluri

@Suite("Community client")
struct CommunityClientTests {

    // MARK: - DTO decoding

    @Test("Decodes feed post row with counts, poll options, and workout snapshot")
    func decodesPostRowWithEmbeds() throws {
        let json = """
        {
          "id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
          "user_id": "11111111-1111-4111-8111-111111111111",
          "title": "Rest day stretch tips",
          "body": "Three easy hip openers.",
          "post_type": "general",
          "image_path": "11111111-1111-4111-8111-111111111111/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.jpg",
          "workout_snapshot": null,
          "created_at": "2026-07-27T20:00:00.000Z",
          "post_likes": [{ "count": 4 }],
          "post_comments": [{ "count": 1 }],
          "post_polls": [
            {
              "id": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
              "question": "Do you take a full rest day?",
              "options": ["Yes", "No"],
              "poll_votes": [
                {
                  "option_index": 0,
                  "user_id": "33333333-3333-4333-8333-333333333333"
                },
                {
                  "option_index": 1,
                  "user_id": "44444444-4444-4444-8444-444444444444"
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let row = try JSONDecoder().decode(CommunityPostRowDTO.self, from: json)
        #expect(row.id == UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"))
        #expect(row.postType == "general")
        #expect(row.postLikes?.first?.count == 4)
        #expect(row.postComments?.first?.count == 1)
        #expect(row.postPolls?.first?.options == ["Yes", "No"])
        #expect(row.postPolls?.first?.pollVotes?.count == 2)
    }

    @Test("Decodes share_workout snapshot snake_case fields")
    func decodesWorkoutSnapshot() throws {
        let json = """
        {
          "session_id": "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee",
          "title": "Chest & Triceps",
          "activity_type": "workout",
          "duration_seconds": 3240,
          "distance_meters": null,
          "set_count": 18,
          "rep_count": 142
        }
        """.data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(WorkoutSnapshot.self, from: json)
        #expect(snapshot.title == "Chest & Triceps")
        #expect(snapshot.activityType == "workout")
        #expect(snapshot.durationSeconds == 3240)
        #expect(snapshot.setCount == 18)
        #expect(snapshot.repCount == 142)
    }

    @Test("Decodes author profile display_name")
    func decodesAuthorProfile() throws {
        let json = """
        {
          "id": "11111111-1111-4111-8111-111111111111",
          "display_name": "Alex"
        }
        """.data(using: .utf8)!

        let author = try JSONDecoder().decode(CommunityAuthorProfileDTO.self, from: json)
        #expect(author.displayName == "Alex")
    }

    // MARK: - Timestamp parsing

    @Test("Parses ISO-8601 created_at with fractional seconds")
    func parsesTimestamps() {
        let date = LiveCommunityClient.parseTimestamp("2026-07-27T20:00:00.123Z")
        #expect(date.timeIntervalSince1970 > 0)

        let plain = LiveCommunityClient.parseTimestamp("2026-07-27T20:00:00Z")
        #expect(plain.timeIntervalSince1970 > 0)
    }

    // MARK: - Mock happy paths

    @Test("Mock feed is chronological and paginates with cursor")
    func mockFeedPagination() async throws {
        let client = MockCommunityClient()
        let first = try await client.fetchFeed(limit: 2, cursor: nil)
        #expect(first.posts.count == 2)
        #expect(first.posts[0].title == "Rest day stretch tips")
        #expect(first.nextCursor != nil)

        let second = try await client.fetchFeed(limit: 2, cursor: first.nextCursor)
        #expect(second.posts.count == 1)
        #expect(second.posts[0].postType == .shareWorkout)
        #expect(second.nextCursor == nil)
    }

    @Test("Mock search filters by query and post type")
    func mockSearch() async throws {
        let client = MockCommunityClient()
        let gear = try await client.search(query: "shoes", types: [.gear], limit: 10, cursor: nil)
        #expect(gear.posts.map(\.id) == [
            UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!
        ])

        let empty = try await client.search(query: "   ", types: nil, limit: 10, cursor: nil)
        #expect(empty.posts.isEmpty)
    }

    @Test("Mock create, like, comment, save, and vote update fixtures")
    func mockEngagementHappyPaths() async throws {
        let client = MockCommunityClient(posts: [])
        let created = try await client.createPost(
            CreateCommunityPostDraft(
                title: "New post",
                body: "This has enough words.",
                postType: .general,
                poll: CreateCommunityPollDraft(question: "Ready?", options: ["Yes", "No"])
            )
        )
        #expect(created.title == "New post")
        #expect(created.poll?.options == ["Yes", "No"])

        try await client.likePost(postId: created.id)
        try await client.savePost(postId: created.id)
        let comment = try await client.addComment(postId: created.id, body: "Nice work")
        #expect(comment.body == "Nice work")

        let pollId = try #require(created.poll?.id)
        try await client.votePoll(pollId: pollId, optionIndex: 0)

        let feed = try await client.fetchFeed(limit: 10, cursor: nil)
        let post = try #require(feed.posts.first)
        #expect(post.isLikedByViewer)
        #expect(post.isSavedByViewer)
        #expect(post.likeCount == 1)
        #expect(post.commentCount == 1)
        #expect(post.poll?.viewerOptionIndex == 0)
        #expect(post.poll?.voteCounts.first == 1)

        let saved = try await client.fetchSaved(limit: 10, cursor: nil)
        #expect(saved.posts.map(\.id) == [created.id])
    }

    @Test("Mock report and hide remove posts; transport error surfaces typed offline")
    func mockModerationAndOffline() async throws {
        var client = MockCommunityClient()
        let firstId = try #require(client.posts.first?.id)
        try await client.hide(postId: firstId)
        #expect(client.posts.contains { $0.id == firstId } == false)

        client.errorToThrow = .transport(CommunityClientError.defaultOfflineMessage)
        await #expect(throws: CommunityClientError.self) {
            _ = try await client.fetchFeed(limit: 10, cursor: nil)
        }
    }

    // MARK: - Unauthorized writes

    @Test("Unauthorized errorToThrow surfaces typed .unauthorized on writes and fetches")
    func unauthorizedTypedThrow() async throws {
        var client = MockCommunityClient(posts: [])
        let created = try await client.createPost(
            CreateCommunityPostDraft(
                title: "Seed",
                body: "one two three",
                postType: .general
            )
        )
        client.errorToThrow = .unauthorized

        await #expect(throws: CommunityClientError.unauthorized) {
            _ = try await client.createPost(
                CreateCommunityPostDraft(
                    title: "Blocked",
                    body: "one two three",
                    postType: .general
                )
            )
        }
        await #expect(throws: CommunityClientError.unauthorized) {
            try await client.likePost(postId: created.id)
        }
        await #expect(throws: CommunityClientError.unauthorized) {
            try await client.savePost(postId: created.id)
        }
        await #expect(throws: CommunityClientError.unauthorized) {
            try await client.report(postId: created.id, reason: "spam")
        }
        await #expect(throws: CommunityClientError.unauthorized) {
            _ = try await client.fetchFeed(limit: 10, cursor: nil)
        }
        await #expect(throws: CommunityClientError.unauthorized) {
            _ = try await client.fetchSaved(limit: 10, cursor: nil)
        }
    }

    // MARK: - Block / report soft-hide

    @Test("Mock block removes all posts by author; report soft-hides the post")
    func mockBlockAndReportSoftHide() async throws {
        var client = MockCommunityClient()
        let authorID = try #require(client.posts.first?.author.id)
        let authorPostCount = client.posts.filter { $0.author.id == authorID }.count
        #expect(authorPostCount >= 2)

        try await client.block(authorId: authorID)
        #expect(client.posts.contains { $0.author.id == authorID } == false)

        client = MockCommunityClient()
        let reportID = try #require(client.posts.first?.id)
        try await client.report(postId: reportID, reason: CommunityReportReason.spam.persistenceValue)
        #expect(client.posts.contains { $0.id == reportID } == false)
    }

    // MARK: - Unlike / unsave round-trip

    @Test("Unlike and unsave round-trip clear viewer flags and adjust counts")
    func unlikeUnsaveRoundTrip() async throws {
        let client = MockCommunityClient(posts: [])
        let created = try await client.createPost(
            CreateCommunityPostDraft(
                title: "Toggle me",
                body: "one two three",
                postType: .general
            )
        )

        try await client.likePost(postId: created.id)
        try await client.savePost(postId: created.id)
        var feed = try await client.fetchFeed(limit: 10, cursor: nil)
        var post = try #require(feed.posts.first)
        #expect(post.isLikedByViewer)
        #expect(post.isSavedByViewer)
        #expect(post.likeCount == 1)

        try await client.unlikePost(postId: created.id)
        try await client.unsavePost(postId: created.id)
        feed = try await client.fetchFeed(limit: 10, cursor: nil)
        post = try #require(feed.posts.first)
        #expect(post.isLikedByViewer == false)
        #expect(post.isSavedByViewer == false)
        #expect(post.likeCount == 0)

        let saved = try await client.fetchSaved(limit: 10, cursor: nil)
        #expect(saved.posts.isEmpty)
    }

    // MARK: - Text rules / report reason / DTO snapshot / notFound

    @Test("CommunityTextRules word count and empty-title gate")
    func textRulesWordCountAndEmptyTitle() {
        #expect(CommunityTextRules.wordCount(in: "  one   two\nthree ") == 3)
        #expect(CommunityTextRules.wordCount(in: "  ") == 0)
        #expect(CommunityTextRules.isValidPost(title: "Hi", body: "one two three"))
        #expect(CommunityTextRules.isValidPost(title: "   ", body: "one two three") == false)
        #expect(CommunityTextRules.isValidPost(title: "Hi", body: "too short") == false)
    }

    @Test("CommunityReportReason persistenceValue matches raw value")
    func reportReasonPersistenceValue() {
        #expect(CommunityReportReason.spam.persistenceValue == "spam")
        #expect(CommunityReportReason.harassment.persistenceValue == "harassment")
        #expect(CommunityReportReason.inappropriate.persistenceValue == "inappropriate")
        #expect(CommunityReportReason.other.persistenceValue == "other")
    }

    @Test("Decodes post row with non-null workout_snapshot")
    func decodesPostRowWithWorkoutSnapshot() throws {
        let json = """
        {
          "id": "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
          "user_id": "11111111-1111-4111-8111-111111111111",
          "title": "Push day complete",
          "body": "Hit every set with one rep in reserve.",
          "post_type": "share_workout",
          "image_path": null,
          "workout_snapshot": {
            "session_id": "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee",
            "title": "Chest & Triceps",
            "activity_type": "workout",
            "duration_seconds": 3240,
            "distance_meters": null,
            "set_count": 18,
            "rep_count": 142
          },
          "created_at": "2026-07-26T20:00:00.000Z",
          "post_likes": [{ "count": 8 }],
          "post_comments": [{ "count": 2 }],
          "post_polls": []
        }
        """.data(using: .utf8)!

        let row = try JSONDecoder().decode(CommunityPostRowDTO.self, from: json)
        let snapshot = try #require(row.workoutSnapshot)
        #expect(row.postType == "share_workout")
        #expect(snapshot.title == "Chest & Triceps")
        #expect(snapshot.setCount == 18)
        #expect(snapshot.repCount == 142)
    }

    @Test("Comment on missing post throws notFound")
    func commentOnMissingPostThrowsNotFound() async {
        let client = MockCommunityClient(posts: [])
        await #expect(throws: CommunityClientError.notFound) {
            _ = try await client.addComment(postId: UUID(), body: "Hello there")
        }
    }
}
