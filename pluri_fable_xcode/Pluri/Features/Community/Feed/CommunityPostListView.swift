import SwiftUI

/// Shared list chrome for feed / saved post lists.
struct CommunityPostListView: View {
    @Bindable var viewModel: CommunityFeedViewModel
    var emptyTitle: String
    var emptyMessage: String

    @State private var commentsPost: CommunityPost?
    @State private var reportPost: CommunityPost?
    @State private var blockAuthor: CommunityAuthor?
    @State private var hidePost: CommunityPost?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: PluriSpacing.md) {
                switch viewModel.loadState {
                case .idle, .loading:
                    ProgressView("Loading Community…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PluriSpacing.xl)
                        .accessibilityLabel("Loading Community")
                case .offline:
                    HomeMessageCard(
                        title: "You're offline",
                        message: CommunityClientError.defaultOfflineMessage
                    )
                case .error(let message):
                    HomeMessageCard(title: "Community unavailable", message: message)
                case .empty:
                    HomeMessageCard(title: emptyTitle, message: emptyMessage)
                case .loaded:
                    ForEach(viewModel.posts) { post in
                        CommunityPostCardView(
                            post: post,
                            onLike: {
                                Task { await viewModel.toggleLike(postID: post.id) }
                            },
                            onComment: { commentsPost = post },
                            onSave: {
                                Task { await viewModel.toggleSave(postID: post.id) }
                            },
                            onVote: { pollID, index in
                                Task { await viewModel.votePoll(pollID: pollID, optionIndex: index) }
                            },
                            onReport: { reportPost = post },
                            onHide: { hidePost = post },
                            onBlock: { blockAuthor = post.author }
                        )
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentPost: post)
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, PluriSpacing.md)
                    }
                }
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.md)
        }
        .scrollIndicators(.hidden)
        .refreshable { viewModel.reload() }
        .sheet(item: $commentsPost) { post in
            CommunityCommentsSheet(post: post) {
                viewModel.applyCommentCountDelta(postID: post.id, delta: 1)
            }
        }
        .sheet(item: $reportPost) { post in
            CommunityReportSheet { reason in
                Task { await viewModel.report(postID: post.id, reason: reason) }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Hide this post?",
            isPresented: Binding(
                get: { hidePost != nil },
                set: { if !$0 { hidePost = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Hide post") {
                if let hidePost {
                    Task { await viewModel.hide(postID: hidePost.id) }
                }
                hidePost = nil
            }
            Button("Cancel", role: .cancel) { hidePost = nil }
        } message: {
            Text("You can always find other posts in Feed.")
        }
        .confirmationDialog(
            "Block \(blockAuthor?.displayName ?? "this author")?",
            isPresented: Binding(
                get: { blockAuthor != nil },
                set: { if !$0 { blockAuthor = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Block author", role: .destructive) {
                if let blockAuthor {
                    Task { await viewModel.block(authorID: blockAuthor.id) }
                }
                blockAuthor = nil
            }
            Button("Cancel", role: .cancel) { blockAuthor = nil }
        } message: {
            Text("Their posts won't show up in your Community feed.")
        }
        .alert(
            "Community",
            isPresented: Binding(
                get: { viewModel.confirmationMessage != nil },
                set: { if !$0 { viewModel.clearConfirmation() } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.clearConfirmation() }
        } message: {
            Text(viewModel.confirmationMessage ?? "")
        }
    }
}
