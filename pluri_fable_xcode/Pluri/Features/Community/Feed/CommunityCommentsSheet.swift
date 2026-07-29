import SwiftUI

/// Comment sheet for a Community post (M8-06).
struct CommunityCommentsSheet: View {
    let post: CommunityPost
    var onCommentAdded: () -> Void

    @Environment(\.communityClient) private var communityClient
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [CommunityComment] = []
    @State private var draft = ""
    @State private var loadState: CommunityLoadState = .idle
    @State private var errorMessage: String?
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                commentsList
                composer
            }
            .background(PluriColor.bgCanvas)
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadComments() }
        }
    }

    @ViewBuilder
    private var commentsList: some View {
        List {
            switch loadState {
            case .idle, .loading:
                ProgressView("Loading comments…")
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            case .offline:
                HomeMessageCard(
                    title: "You're offline",
                    message: CommunityClientError.defaultOfflineMessage
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            case .error(let message):
                HomeMessageCard(title: "Comments unavailable", message: message)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            case .empty:
                HomeMessageCard(
                    title: "No comments yet",
                    message: "Be the first to leave a kind note."
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            case .loaded:
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                        Text(comment.author.displayName)
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textPrimary)
                        Text(comment.body)
                            .font(PluriFont.body)
                            .foregroundStyle(PluriColor.textSecondary)
                    }
                    .padding(.vertical, PluriSpacing.xs)
                    .accessibilityElement(children: .combine)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(PluriFont.overline)
                    .foregroundStyle(PluriColor.textSecondary)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var composer: some View {
        HStack(spacing: PluriSpacing.sm) {
            TextField("Add a comment", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .font(PluriFont.body)
                .padding(PluriSpacing.sm)
                .background(PluriColor.bgSurface, in: .rect(cornerRadius: 12))

            Button("Post", systemImage: "arrow.up.circle.fill") {
                Task { await sendComment() }
            }
            .labelStyle(.iconOnly)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Post comment")
        }
        .padding(PluriSpacing.md)
        .background(PluriColor.bgCanvas)
    }

    private func loadComments() async {
        loadState = .loading
        do {
            comments = try await communityClient.fetchComments(postId: post.id, limit: 50)
            loadState = comments.isEmpty ? .empty : .loaded
        } catch let error as CommunityClientError {
            comments = []
            switch error {
            case .transport:
                loadState = .offline
            default:
                loadState = .error(error.errorDescription ?? "We couldn't load comments.")
            }
        } catch {
            comments = []
            loadState = .error("We couldn't load comments.")
        }
    }

    private func sendComment() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        isSending = true
        defer { isSending = false }
        do {
            let comment = try await communityClient.addComment(postId: post.id, body: trimmed)
            comments.append(comment)
            draft = ""
            loadState = .loaded
            errorMessage = nil
            onCommentAdded()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "We couldn't post that comment."
        }
    }
}
