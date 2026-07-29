import Foundation
import Observation

/// Shared load-state for Community list surfaces (feed / saved / search).
enum CommunityLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case empty
    case offline
    case error(String)
}

/// Feed list logic (M8-05 / M8-06 / M8-09 / M8-11): chronological posts with
/// like / save / poll / moderation that update the local list honestly.
@MainActor
@Observable
final class CommunityFeedViewModel {
    private(set) var posts: [CommunityPost] = []
    private(set) var loadState: CommunityLoadState = .idle
    private(set) var nextCursor: CommunityFeedCursor?
    private(set) var isLoadingMore = false
    var confirmationMessage: String?

    private let client: any CommunityClient
    private let reachability: any NetworkReachability
    private let mode: Mode
    private var loadTask: Task<Void, Never>?

    enum Mode: Sendable {
        case feed
        case saved
    }

    init(
        client: any CommunityClient,
        mode: Mode = .feed,
        reachability: (any NetworkReachability)? = nil
    ) {
        self.client = client
        self.mode = mode
        self.reachability = reachability ?? PathMonitorReachability()
        self.reachability.start()
    }

    func reload() {
        loadTask?.cancel()
        loadTask = Task { await load(reset: true) }
    }

    func loadMoreIfNeeded(currentPost: CommunityPost) {
        guard currentPost.id == posts.last?.id,
              nextCursor != nil,
              !isLoadingMore,
              loadState == .loaded
        else { return }
        loadTask = Task { await load(reset: false) }
    }

    func toggleLike(postID: UUID) async {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        let post = posts[index]
        do {
            if post.isLikedByViewer {
                try await client.unlikePost(postId: postID)
                posts[index] = post.updating(
                    likeCount: max(0, post.likeCount - 1),
                    isLikedByViewer: false
                )
            } else {
                try await client.likePost(postId: postID)
                posts[index] = post.updating(
                    likeCount: post.likeCount + 1,
                    isLikedByViewer: true
                )
            }
        } catch {
            confirmationMessage = gentleErrorMessage(error)
        }
    }

    func toggleSave(postID: UUID) async {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        let post = posts[index]
        do {
            if post.isSavedByViewer {
                try await client.unsavePost(postId: postID)
                if mode == .saved {
                    posts.remove(at: index)
                    if posts.isEmpty { loadState = .empty }
                } else {
                    posts[index] = post.updating(isSavedByViewer: false)
                }
            } else {
                try await client.savePost(postId: postID)
                posts[index] = post.updating(isSavedByViewer: true)
            }
        } catch {
            confirmationMessage = gentleErrorMessage(error)
        }
    }

    func votePoll(pollID: UUID, optionIndex: Int) async {
        guard let index = posts.firstIndex(where: { $0.poll?.id == pollID }),
              let poll = posts[index].poll
        else { return }
        do {
            try await client.votePoll(pollId: pollID, optionIndex: optionIndex)
            var counts = poll.voteCounts
            if counts.count != poll.options.count {
                counts = Array(repeating: 0, count: poll.options.count)
            }
            if let previous = poll.viewerOptionIndex,
               previous >= 0, previous < counts.count {
                counts[previous] = max(0, counts[previous] - 1)
            }
            if optionIndex >= 0, optionIndex < counts.count {
                counts[optionIndex] += 1
            }
            let updatedPoll = CommunityPoll(
                id: poll.id,
                question: poll.question,
                options: poll.options,
                voteCounts: counts,
                viewerOptionIndex: optionIndex
            )
            posts[index] = posts[index].updating(poll: updatedPoll)
        } catch {
            confirmationMessage = gentleErrorMessage(error)
        }
    }

    func applyCommentCountDelta(postID: UUID, delta: Int) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        let post = posts[index]
        posts[index] = post.updating(commentCount: max(0, post.commentCount + delta))
    }

    func report(postID: UUID, reason: CommunityReportReason) async {
        do {
            try await client.report(postId: postID, reason: reason.persistenceValue)
            removePostLocally(postID)
            confirmationMessage = "Thanks — we hid that post for you."
        } catch {
            confirmationMessage = gentleErrorMessage(error)
        }
    }

    func hide(postID: UUID) async {
        do {
            try await client.hide(postId: postID)
            removePostLocally(postID)
            confirmationMessage = "Post hidden from your feed."
        } catch {
            confirmationMessage = gentleErrorMessage(error)
        }
    }

    func block(authorID: UUID) async {
        do {
            try await client.block(authorId: authorID)
            posts.removeAll { $0.author.id == authorID }
            if posts.isEmpty, loadState == .loaded || loadState == .empty {
                loadState = posts.isEmpty ? .empty : .loaded
            }
            confirmationMessage = "Author blocked. Their posts won't show up here."
        } catch {
            confirmationMessage = gentleErrorMessage(error)
        }
    }

    func clearConfirmation() {
        confirmationMessage = nil
    }

    // MARK: - Private

    private func load(reset: Bool) async {
        if reset {
            loadState = .loading
            nextCursor = nil
        } else {
            isLoadingMore = true
        }

        guard reachability.isOnline else {
            if reset {
                posts = []
                loadState = .offline
            }
            isLoadingMore = false
            return
        }

        do {
            let page: CommunityFeedPage
            switch mode {
            case .feed:
                page = try await client.fetchFeed(limit: 20, cursor: reset ? nil : nextCursor)
            case .saved:
                page = try await client.fetchSaved(limit: 20, cursor: reset ? nil : nextCursor)
            }

            if reset {
                posts = page.posts
            } else {
                let existing = Set(posts.map(\.id))
                posts.append(contentsOf: page.posts.filter { !existing.contains($0.id) })
            }
            nextCursor = page.nextCursor
            loadState = posts.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            return
        } catch let error as CommunityClientError {
            if reset {
                posts = []
                loadState = mapClientError(error)
            } else {
                confirmationMessage = gentleErrorMessage(error)
            }
        } catch {
            if reset {
                posts = []
                loadState = .error(
                    (error as? LocalizedError)?.errorDescription
                        ?? CommunityClientError.defaultOfflineMessage
                )
            }
        }

        isLoadingMore = false
    }

    private func removePostLocally(_ postID: UUID) {
        posts.removeAll { $0.id == postID }
        if posts.isEmpty { loadState = .empty }
    }

    private func mapClientError(_ error: CommunityClientError) -> CommunityLoadState {
        switch error {
        case .transport:
            .offline
        case .unauthorized:
            .error(error.errorDescription ?? "Sign in to use Community.")
        default:
            .error(error.errorDescription ?? CommunityClientError.defaultOfflineMessage)
        }
    }

    private func gentleErrorMessage(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription
            ?? "Something went wrong. Check your connection and try again."
    }
}

extension CommunityPost {
    func updating(
        likeCount: Int? = nil,
        commentCount: Int? = nil,
        isLikedByViewer: Bool? = nil,
        isSavedByViewer: Bool? = nil,
        poll: CommunityPoll? = nil
    ) -> CommunityPost {
        CommunityPost(
            id: id,
            author: author,
            title: title,
            body: body,
            postType: postType,
            imageURL: imageURL,
            workoutSnapshot: workoutSnapshot,
            poll: poll ?? self.poll,
            likeCount: likeCount ?? self.likeCount,
            commentCount: commentCount ?? self.commentCount,
            isLikedByViewer: isLikedByViewer ?? self.isLikedByViewer,
            isSavedByViewer: isSavedByViewer ?? self.isSavedByViewer,
            createdAt: createdAt
        )
    }
}
