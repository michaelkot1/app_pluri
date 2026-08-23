import SwiftUI

/// Instagram-style Community post card (M8-06 / M8-11 / M8-16).
struct CommunityPostCardView: View {
    let post: CommunityPost
    var onLike: () -> Void
    var onComment: () -> Void
    var onSave: () -> Void
    var onVote: (UUID, Int) -> Void
    var onReport: () -> Void
    var onHide: () -> Void
    var onBlock: () -> Void

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                header
                Text(post.title)
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(post.body)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textSecondary)

                if let imageURL = post.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 160, maxHeight: 280)
                                .clipped()
                                .clipShape(.rect(cornerRadius: 12))
                        case .failure:
                            EmptyView()
                        default:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, PluriSpacing.lg)
                        }
                    }
                    .accessibilityLabel("Post image")
                }

                if let snapshot = post.workoutSnapshot {
                    workoutSnapshotBlock(snapshot)
                }

                if let poll = post.poll {
                    pollBlock(poll)
                }

                Divider()
                    .overlay(PluriColor.lineDivider)
                actions
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: PluriSpacing.sm) {
            Text(post.author.initial)
                .font(PluriFont.label)
                .bold()
                .foregroundStyle(PluriColor.brandOrangeDeep)
                .frame(width: 44, height: 44)
                .background(PluriColor.brandCoralSoft.opacity(0.18), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                Text(post.author.displayName)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textPrimary)
                HStack(spacing: PluriSpacing.xs) {
                    Text(post.postType.createTitle)
                    Text("·")
                    Text(post.createdAt, format: .relative(presentation: .named))
                }
                .font(PluriFont.overline)
                .foregroundStyle(PluriColor.textTertiary)
            }
            Spacer(minLength: 0)
            Menu {
                Button("Report…", systemImage: "flag", action: onReport)
                Button("Hide post", systemImage: "eye.slash", action: onHide)
                Button("Block author", systemImage: "hand.raised", role: .destructive, action: onBlock)
            } label: {
                Label("More", systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Post options")
        }
    }

    private func workoutSnapshotBlock(_ snapshot: WorkoutSnapshot) -> some View {
        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
            Text(snapshot.title ?? "Workout")
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textPrimary)
            HStack(spacing: PluriSpacing.md) {
                if let duration = snapshot.durationSeconds {
                    Text(
                        Duration.seconds(duration),
                        format: .units(allowed: [.minutes, .seconds], width: .abbreviated)
                    )
                }
                if let sets = snapshot.setCount {
                    Text("\(sets.formatted(.number)) sets")
                }
                if let reps = snapshot.repCount {
                    Text("\(reps.formatted(.number)) reps")
                }
            }
            .font(PluriFont.overline)
            .foregroundStyle(PluriColor.textSecondary)
        }
        .padding(PluriSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PluriColor.bgMuted, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Shared workout \(snapshot.title ?? "session")")
    }

    private func pollBlock(_ poll: CommunityPoll) -> some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text(poll.question)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textPrimary)
            ForEach(poll.options.enumerated(), id: \.offset) { index, option in
                let count = index < poll.voteCounts.count ? poll.voteCounts[index] : 0
                let isSelected = poll.viewerOptionIndex == index
                Button {
                    onVote(poll.id, index)
                } label: {
                    HStack {
                        Text(option)
                            .font(PluriFont.body)
                            .foregroundStyle(PluriColor.textPrimary)
                        Spacer(minLength: 0)
                        Text(count, format: .number)
                            .font(PluriFont.overline)
                            .foregroundStyle(PluriColor.textSecondary)
                    }
                    .padding(.horizontal, PluriSpacing.md)
                    .frame(minHeight: 44)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        isSelected ? PluriColor.brandOrange.opacity(0.15) : PluriColor.bgMuted,
                        in: .rect(cornerRadius: 12)
                    )
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(PluriColor.brandOrange, lineWidth: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option), \(count) votes")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var actions: some View {
        HStack(spacing: PluriSpacing.sm) {
            Button {
                onLike()
            } label: {
                Label {
                    Text(post.likeCount, format: .number)
                } icon: {
                    Image(systemName: post.isLikedByViewer ? "heart.fill" : "heart")
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(post.isLikedByViewer ? PluriColor.brandOrange : PluriColor.textSecondary)
            .accessibilityLabel("\(post.likeCount) likes")
            .accessibilityHint(post.isLikedByViewer ? "Unlike" : "Like")

            Button {
                onComment()
            } label: {
                Label {
                    Text(post.commentCount, format: .number)
                } icon: {
                    Image(systemName: "bubble.right")
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(PluriColor.textSecondary)
            .accessibilityLabel("\(post.commentCount) comments")
            .accessibilityHint("View comments")

            Spacer(minLength: 0)

            Button {
                onSave()
            } label: {
                Image(systemName: post.isSavedByViewer ? "bookmark.fill" : "bookmark")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(post.isSavedByViewer ? PluriColor.brandOrange : PluriColor.textSecondary)
            .accessibilityLabel(post.isSavedByViewer ? "Unsave post" : "Save post")
        }
    }
}

#Preview("Poll card") {
    let post = [CommunityPost].communityPreviewFixtures.first { $0.poll != nil }
    if let post {
        CommunityPostCardView(
            post: post,
            onLike: {},
            onComment: {},
            onSave: {},
            onVote: { _, _ in },
            onReport: {},
            onHide: {},
            onBlock: {}
        )
        .padding()
        .background(PluriColor.bgCanvas)
    }
}

#Preview("Workout snapshot card") {
    let post = [CommunityPost].communityPreviewFixtures.first { $0.workoutSnapshot != nil }
    if let post {
        CommunityPostCardView(
            post: post,
            onLike: {},
            onComment: {},
            onSave: {},
            onVote: { _, _ in },
            onReport: {},
            onHide: {},
            onBlock: {}
        )
        .padding()
        .background(PluriColor.bgCanvas)
    }
}
