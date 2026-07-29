import SwiftUI

/// Saved hub segment (M8-09).
struct CommunitySavedView: View {
    @Bindable var viewModel: CommunityFeedViewModel

    var body: some View {
        CommunityPostListView(
            viewModel: viewModel,
            emptyTitle: "No saved posts",
            emptyMessage: "Bookmark posts from Feed and they'll show up here."
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        CommunitySavedPreviewHost()
    }
    .background(PluriColor.bgCanvas)
}

private struct CommunitySavedPreviewHost: View {
    @State private var viewModel = CommunityFeedViewModel(
        client: MockCommunityClient(posts: []),
        mode: .saved,
        reachability: AlwaysOnlineReachability()
    )

    var body: some View {
        CommunitySavedView(viewModel: viewModel)
            .task { viewModel.reload() }
    }
}
