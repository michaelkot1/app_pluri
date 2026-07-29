import SwiftUI

/// Community search pushed from the hub toolbar (M8-08).
struct CommunitySearchView: View {
    @Environment(\.communityClient) private var communityClient
    @State private var viewModel: CommunitySearchViewModel?

    /// Production leaves `viewModel` nil and builds from the environment client;
    /// previews may seed a configured view model (offline / empty).
    init(viewModel: CommunitySearchViewModel? = nil) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if let viewModel {
                searchContent(viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PluriColor.bgCanvas)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = CommunitySearchViewModel(client: communityClient)
            }
        }
    }

    @ViewBuilder
    private func searchContent(_ viewModel: CommunitySearchViewModel) -> some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                TextField("Search posts", text: $viewModel.query)
                    .font(PluriFont.body)
                    .padding(PluriSpacing.md)
                    .frame(minHeight: 44)
                    .background(PluriColor.bgSurface, in: .rect(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(PluriColor.lineDivider, lineWidth: 1)
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { viewModel.search() }
                    .onChange(of: viewModel.query) { _, _ in
                        viewModel.search()
                    }
                    .accessibilityLabel("Search Community posts")

                typeChips(viewModel: viewModel)
                results(viewModel: viewModel)
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.md)
        }
        .scrollIndicators(.hidden)
    }

    private func typeChips(viewModel: CommunitySearchViewModel) -> some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text("Type")
                .font(PluriFont.overline)
                .foregroundStyle(PluriColor.textSecondary)
                .textCase(.uppercase)

            ScrollView(.horizontal) {
                HStack(spacing: PluriSpacing.sm) {
                    ForEach(CommunityPostType.allCases, id: \.self) { type in
                        PluriChip(
                            title: LocalizedStringKey(type.createTitle),
                            isSelected: viewModel.selectedTypes.contains(type)
                        ) {
                            viewModel.toggleType(type)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Post type filters")
        }
    }

    @ViewBuilder
    private func results(viewModel: CommunitySearchViewModel) -> some View {
        VStack(alignment: .leading, spacing: PluriSpacing.md) {
            Text("Results")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            switch viewModel.loadState {
            case .idle:
                HomeMessageCard(
                    title: "Search Community",
                    message: "Try a keyword like shoes, stretch, or recipe."
                )
            case .loading:
                ProgressView("Searching…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PluriSpacing.xl)
            case .offline:
                HomeMessageCard(
                    title: "You're offline",
                    message: CommunityClientError.defaultOfflineMessage
                )
            case .error(let message):
                HomeMessageCard(title: "Search unavailable", message: message)
            case .empty:
                HomeMessageCard(
                    title: "No matches",
                    message: "Nothing matched that search. Try different words or clear a type filter."
                )
            case .loaded:
                ForEach(viewModel.posts) { post in
                    PluriCard {
                        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                            Text(post.author.displayName)
                                .font(PluriFont.overline)
                                .foregroundStyle(PluriColor.textTertiary)
                            Text(post.title)
                                .font(PluriFont.label)
                                .foregroundStyle(PluriColor.textPrimary)
                            Text(post.body)
                                .font(PluriFont.body)
                                .foregroundStyle(PluriColor.textSecondary)
                                .lineLimit(3)
                            Text("\(post.likeCount.formatted(.number)) likes · \(post.commentCount.formatted(.number)) comments")
                                .font(PluriFont.overline)
                                .foregroundStyle(PluriColor.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

#Preview("Empty") {
    NavigationStack {
        CommunitySearchPreviewHost(
            query: "zzzz-no-match",
            reachability: AlwaysOnlineReachability()
        )
    }
    .background(PluriColor.bgCanvas)
}

#Preview("Offline") {
    NavigationStack {
        CommunitySearchPreviewHost(
            query: "shoes",
            reachability: MockNetworkReachability(isOnline: false)
        )
    }
    .background(PluriColor.bgCanvas)
}

private struct CommunitySearchPreviewHost: View {
    @State private var viewModel: CommunitySearchViewModel
    private let query: String

    init(query: String, reachability: any NetworkReachability) {
        self.query = query
        _viewModel = State(
            initialValue: CommunitySearchViewModel(
                client: MockCommunityClient(),
                reachability: reachability
            )
        )
    }

    var body: some View {
        CommunitySearchView(viewModel: viewModel)
            .task {
                viewModel.query = query
                viewModel.search()
            }
    }
}
