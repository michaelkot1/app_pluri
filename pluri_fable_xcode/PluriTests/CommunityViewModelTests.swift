import Foundation
import SwiftData
import Testing
@testable import Pluri

@Suite("Community UI view models")
@MainActor
struct CommunityViewModelTests {

    @Test("Create Post enables only with title and at least three body words")
    func createPostGating() {
        let vm = CreateCommunityPostViewModel(client: MockCommunityClient(posts: []))
        #expect(vm.canPost == false)

        vm.title = "Hello"
        vm.body = "two words"
        #expect(vm.canPost == false)

        vm.body = "one two three"
        #expect(vm.canPost == true)

        vm.postType = .shareWorkout
        #expect(vm.canPost == false)

        vm.selectedSnapshot = WorkoutSnapshot(
            sessionId: UUID(),
            title: "Push",
            activityType: "workout",
            durationSeconds: 1_800,
            distanceMeters: nil,
            setCount: 10,
            repCount: 80
        )
        #expect(vm.canPost == true)
    }

    @Test("Feed VM shows offline without inventing posts")
    func feedOffline() async {
        let reachability = MockNetworkReachability(isOnline: false)
        let vm = CommunityFeedViewModel(
            client: MockCommunityClient(),
            mode: .feed,
            reachability: reachability
        )
        vm.reload()
        await waitUntil { vm.loadState != .idle && vm.loadState != .loading }

        #expect(vm.loadState == .offline)
        #expect(vm.posts.isEmpty)
    }

    @Test("Feed like, save, hide, and report update the local list")
    func feedEngagementAndModeration() async throws {
        let client = MockCommunityClient()
        // Use the gear post — not already saved — so toggleSave turns save on.
        let targetID = try #require(
            client.posts.first(where: { $0.postType == .gear })?.id
        )
        let reachability = MockNetworkReachability(isOnline: true)
        let vm = CommunityFeedViewModel(
            client: client,
            mode: .feed,
            reachability: reachability
        )
        vm.reload()
        await waitUntil { vm.loadState == .loaded }

        await vm.toggleLike(postID: targetID)
        let liked = try #require(vm.posts.first(where: { $0.id == targetID }))
        #expect(liked.isLikedByViewer == false) // fixture starts liked; toggle unlikes
        #expect(liked.likeCount == 1)

        await vm.toggleSave(postID: targetID)
        let saved = try #require(vm.posts.first(where: { $0.id == targetID }))
        #expect(saved.isSavedByViewer == true)

        await vm.hide(postID: targetID)
        #expect(vm.posts.contains { $0.id == targetID } == false)

        let reportID = try #require(vm.posts.first?.id)
        await vm.report(postID: reportID, reason: .spam)
        #expect(vm.posts.contains { $0.id == reportID } == false)
        #expect(vm.confirmationMessage != nil)
    }

    @Test("Mock block removes the author's posts from the feed list")
    func feedBlockRemovesAuthor() async throws {
        let client = MockCommunityClient()
        let authorID = try #require(client.posts.first?.author.id)
        let reachability = MockNetworkReachability(isOnline: true)
        let vm = CommunityFeedViewModel(
            client: client,
            mode: .feed,
            reachability: reachability
        )
        vm.reload()
        await waitUntil { vm.loadState == .loaded }

        await vm.block(authorID: authorID)
        #expect(vm.posts.contains { $0.author.id == authorID } == false)
    }

    @Test("Search filters by query and type chips")
    func searchFilters() async {
        let reachability = MockNetworkReachability(isOnline: true)
        let vm = CommunitySearchViewModel(
            client: MockCommunityClient(),
            reachability: reachability
        )
        vm.query = "shoes"
        vm.selectedTypes = [.gear]
        vm.search()
        await waitUntil { vm.loadState == .loaded || vm.loadState == .empty }

        #expect(vm.posts.count == 1)
        #expect(vm.posts.first?.postType == .gear)
    }

    @Test("fetchRepliesToMyPosts orders newest first and excludes self-comments")
    func repliesExcludeSelfAndOrder() async throws {
        let myPostID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        let otherAuthor = CommunityAuthor(
            id: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
            displayName: "Sam"
        )
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = Date(timeIntervalSince1970: 1_700_000_100)

        var client = MockCommunityClient(
            posts: [
                CommunityPost(
                    id: myPostID,
                    author: CommunityAuthor(id: MockCommunityClient.viewerAuthorID, displayName: "You"),
                    title: "My post",
                    body: "This has three words",
                    postType: .general,
                    imageURL: nil,
                    workoutSnapshot: nil,
                    poll: nil,
                    likeCount: 0,
                    commentCount: 2,
                    isLikedByViewer: false,
                    isSavedByViewer: false,
                    createdAt: older
                ),
            ],
            commentsByPostId: [
                myPostID: [
                    CommunityComment(
                        id: UUID(uuidString: "11111111-1111-4111-8111-111111111101")!,
                        postId: myPostID,
                        author: CommunityAuthor(id: MockCommunityClient.viewerAuthorID, displayName: "You"),
                        body: "Self comment",
                        createdAt: newer
                    ),
                    CommunityComment(
                        id: UUID(uuidString: "11111111-1111-4111-8111-111111111102")!,
                        postId: myPostID,
                        author: otherAuthor,
                        body: "Older reply",
                        createdAt: older
                    ),
                    CommunityComment(
                        id: UUID(uuidString: "11111111-1111-4111-8111-111111111103")!,
                        postId: myPostID,
                        author: otherAuthor,
                        body: "Newer reply",
                        createdAt: newer
                    ),
                ],
            ]
        )

        let replies = try await client.fetchRepliesToMyPosts(limit: 10)
        #expect(replies.count == 2)
        #expect(replies[0].comment.body == "Newer reply")
        #expect(replies[1].comment.body == "Older reply")
        #expect(replies.allSatisfy { $0.comment.author.id != MockCommunityClient.viewerAuthorID })
    }

    @Test("WorkoutSnapshot builds compact counts from a session fixture")
    func workoutSnapshotBuilder() throws {
        let container = try ModelContainer(
            for: Schema([WorkoutSessionRecord.self, SetLogRecord.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let session = WorkoutSessionRecord(
            userId: UUID(),
            planWorkoutId: UUID(),
            activityType: "workout",
            endedAt: .now,
            durationSeconds: 2_400
        )
        context.insert(session)
        let setOne = SetLogRecord(
            workoutExerciseId: nil,
            exerciseName: "Bench",
            setNumber: 1,
            reps: 8
        )
        setOne.session = session
        context.insert(setOne)
        let setTwo = SetLogRecord(
            workoutExerciseId: nil,
            exerciseName: "Bench",
            setNumber: 2,
            reps: 6
        )
        setTwo.session = session
        context.insert(setTwo)
        try context.save()

        let snapshot = WorkoutSnapshot.from(session: session, title: "Chest day")
        #expect(snapshot.title == "Chest day")
        #expect(snapshot.durationSeconds == 2_400)
        #expect(snapshot.setCount == 2)
        #expect(snapshot.repCount == 14)
        #expect(snapshot.activityType == "workout")
    }

    @Test("Mock createPost rejects bodies under three words")
    func createPostWordFloor() async {
        let client = MockCommunityClient(posts: [])
        await #expect(throws: CommunityClientError.self) {
            _ = try await client.createPost(
                CreateCommunityPostDraft(
                    title: "Title",
                    body: "too short",
                    postType: .general
                )
            )
        }
    }

    @Test("Feed reload with unauthorized maps to error and empties posts")
    func feedUnauthorizedError() async {
        var client = MockCommunityClient()
        client.errorToThrow = .unauthorized
        let vm = CommunityFeedViewModel(
            client: client,
            mode: .feed,
            reachability: MockNetworkReachability(isOnline: true)
        )
        vm.reload()
        await waitUntil { vm.loadState != .idle && vm.loadState != .loading }

        guard case .error(let message) = vm.loadState else {
            Issue.record("Expected .error, got \(vm.loadState)")
            return
        }
        #expect(message.localizedStandardContains("Sign in"))
        #expect(vm.posts.isEmpty)
    }

    @Test("Search reload with unauthorized maps to error and empties posts")
    func searchUnauthorizedError() async {
        var client = MockCommunityClient()
        client.errorToThrow = .unauthorized
        let vm = CommunitySearchViewModel(
            client: client,
            reachability: MockNetworkReachability(isOnline: true)
        )
        vm.query = "shoes"
        vm.search()
        await waitUntil { vm.loadState != .idle && vm.loadState != .loading }

        guard case .error(let message) = vm.loadState else {
            Issue.record("Expected .error, got \(vm.loadState)")
            return
        }
        #expect(message.localizedStandardContains("Sign in"))
        #expect(vm.posts.isEmpty)
    }

    @Test("Saved mode empty when no bookmarks; offline when unreachable")
    func savedEmptyAndOffline() async {
        let emptyClient = MockCommunityClient(posts: [])
        let emptyVM = CommunityFeedViewModel(
            client: emptyClient,
            mode: .saved,
            reachability: MockNetworkReachability(isOnline: true)
        )
        emptyVM.reload()
        await waitUntil { emptyVM.loadState != .idle && emptyVM.loadState != .loading }
        #expect(emptyVM.loadState == .empty)
        #expect(emptyVM.posts.isEmpty)

        let offlineVM = CommunityFeedViewModel(
            client: MockCommunityClient(),
            mode: .saved,
            reachability: MockNetworkReachability(isOnline: false)
        )
        offlineVM.reload()
        await waitUntil { offlineVM.loadState != .idle && offlineVM.loadState != .loading }
        #expect(offlineVM.loadState == .offline)
        #expect(offlineVM.posts.isEmpty)
    }

    @Test("votePoll updates local poll counts and viewer option index")
    func votePollUpdatesLocalPoll() async throws {
        let client = MockCommunityClient()
        let pollID = try #require(
            client.posts.first(where: { $0.poll != nil })?.poll?.id
        )
        let beforeCounts = try #require(
            client.posts.first(where: { $0.poll?.id == pollID })?.poll?.voteCounts
        )
        let vm = CommunityFeedViewModel(
            client: client,
            mode: .feed,
            reachability: MockNetworkReachability(isOnline: true)
        )
        vm.reload()
        await waitUntil { vm.loadState == .loaded }

        await vm.votePoll(pollID: pollID, optionIndex: 0)
        let updated = try #require(vm.posts.first(where: { $0.poll?.id == pollID })?.poll)
        #expect(updated.viewerOptionIndex == 0)
        #expect(updated.voteCounts[0] == beforeCounts[0] + 1)
    }
}

@MainActor
private func waitUntil(_ condition: @MainActor () -> Bool) async {
    let start = ContinuousClock.now
    while !condition() {
        if ContinuousClock.now - start > .seconds(2) {
            return
        }
        try? await Task.sleep(for: .milliseconds(20))
    }
}
