import Foundation
import Observation

/// Notifications Community replies loader (M8-12 / SPEC §5.3).
@MainActor
@Observable
final class CommunityRepliesViewModel {
    private(set) var replies: [CommunityReplyNotification] = []
    private(set) var loadState: CommunityLoadState = .idle

    private let client: any CommunityClient
    private let reachability: any NetworkReachability

    init(
        client: any CommunityClient,
        reachability: (any NetworkReachability)? = nil
    ) {
        self.client = client
        self.reachability = reachability ?? PathMonitorReachability()
        self.reachability.start()
    }

    func reload() {
        Task { await load() }
    }

    func load() async {
        loadState = .loading
        guard reachability.isOnline else {
            replies = []
            loadState = .offline
            return
        }

        do {
            replies = try await client.fetchRepliesToMyPosts(limit: 20)
            loadState = replies.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            return
        } catch let error as CommunityClientError {
            replies = []
            switch error {
            case .transport:
                loadState = .offline
            case .unauthorized:
                loadState = .error(error.errorDescription ?? "Sign in to see replies.")
            default:
                loadState = .error(
                    error.errorDescription ?? "We couldn't load replies right now."
                )
            }
        } catch {
            replies = []
            loadState = .error("We couldn't load replies right now.")
        }
    }
}
