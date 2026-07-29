import Foundation
import Observation

/// Community search logic (M8-08 / SPEC §11): query + optional type chips.
@MainActor
@Observable
final class CommunitySearchViewModel {
    var query = ""
    var selectedTypes: Set<CommunityPostType> = []
    private(set) var posts: [CommunityPost] = []
    private(set) var loadState: CommunityLoadState = .idle

    private let client: any CommunityClient
    private let reachability: any NetworkReachability
    private var searchTask: Task<Void, Never>?

    init(
        client: any CommunityClient,
        reachability: (any NetworkReachability)? = nil
    ) {
        self.client = client
        self.reachability = reachability ?? PathMonitorReachability()
        self.reachability.start()
    }

    func toggleType(_ type: CommunityPostType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
        search()
    }

    func search() {
        searchTask?.cancel()
        searchTask = Task { await performSearch() }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            posts = []
            loadState = .idle
            return
        }

        loadState = .loading
        guard reachability.isOnline else {
            posts = []
            loadState = .offline
            return
        }

        do {
            let types = selectedTypes.isEmpty ? nil : Array(selectedTypes)
            let page = try await client.search(
                query: trimmed,
                types: types,
                limit: 30,
                cursor: nil
            )
            posts = page.posts
            loadState = posts.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            return
        } catch let error as CommunityClientError {
            posts = []
            switch error {
            case .transport:
                loadState = .offline
            default:
                loadState = .error(
                    error.errorDescription ?? CommunityClientError.defaultOfflineMessage
                )
            }
        } catch {
            posts = []
            loadState = .error(
                (error as? LocalizedError)?.errorDescription
                    ?? CommunityClientError.defaultOfflineMessage
            )
        }
    }
}
