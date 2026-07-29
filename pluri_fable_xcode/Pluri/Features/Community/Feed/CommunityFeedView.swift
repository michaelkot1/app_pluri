import SwiftUI

/// Feed segment (M8-06) with create-post entry.
struct CommunityFeedView: View {
    @Bindable var viewModel: CommunityFeedViewModel
    var onCreatePost: () -> Void

    var body: some View {
        CommunityPostListView(
            viewModel: viewModel,
            emptyTitle: "Start the conversation",
            emptyMessage: "Share a win, ask a question, or post a workout for the Community."
        )
        .safeAreaInset(edge: .bottom) {
            Button("Create post", systemImage: "plus") {
                onCreatePost()
            }
            .buttonStyle(.pluriPrimary)
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.sm)
            .background(PluriColor.bgCanvas.opacity(0.96))
            .accessibilityLabel("Create post")
            .accessibilityHint("Compose a new Community post")
        }
    }
}

#Preview("Empty") {
    NavigationStack {
        CommunityFeedPreviewHost(
            client: MockCommunityClient(posts: []),
            mode: .feed,
            reachability: AlwaysOnlineReachability()
        )
    }
    .background(PluriColor.bgCanvas)
}

#Preview("Offline") {
    NavigationStack {
        CommunityFeedPreviewHost(
            client: MockCommunityClient(),
            mode: .feed,
            reachability: MockNetworkReachability(isOnline: false)
        )
    }
    .background(PluriColor.bgCanvas)
}

#Preview("Error") {
    NavigationStack {
        CommunityFeedPreviewHost(
            client: MockCommunityClient(errorToThrow: .unauthorized),
            mode: .feed,
            reachability: AlwaysOnlineReachability()
        )
    }
    .background(PluriColor.bgCanvas)
}

/// Preview-only host that reloads the feed VM on appear.
private struct CommunityFeedPreviewHost: View {
    @State private var viewModel: CommunityFeedViewModel

    init(
        client: any CommunityClient,
        mode: CommunityFeedViewModel.Mode,
        reachability: any NetworkReachability
    ) {
        _viewModel = State(
            initialValue: CommunityFeedViewModel(
                client: client,
                mode: mode,
                reachability: reachability
            )
        )
    }

    var body: some View {
        CommunityFeedView(viewModel: viewModel, onCreatePost: {})
            .task { viewModel.reload() }
    }
}
