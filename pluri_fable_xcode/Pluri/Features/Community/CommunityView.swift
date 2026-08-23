import SwiftData
import SwiftUI

/// Community root shell (M8-05…M8-12): Feed · Discover · Saved hub chrome,
/// search + calendar on the Community stack, create-post sheet.
///
/// Create-post SwiftData / PlanStore lookups live on the sheet only so opening
/// the Community tab cannot crash the hub (BUG-001).
struct CommunityView: View {
    @Environment(MainRouter.self) private var router
    @Environment(\.communityClient) private var communityClient

    @State private var selectedTab: CommunityHubTab = .feed
    @State private var feedViewModel: CommunityFeedViewModel?
    @State private var savedViewModel: CommunityFeedViewModel?
    @State private var createViewModel: CreateCommunityPostViewModel?

    var body: some View {
        Group {
            if let feedViewModel, let savedViewModel {
                CommunityHubContent(
                    selectedTab: $selectedTab,
                    feedViewModel: feedViewModel,
                    savedViewModel: savedViewModel,
                    onCreatePost: presentCreatePost
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Loading Community")
            }
        }
        .background(PluriColor.bgCanvas)
        .navigationTitle("Community")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Search", systemImage: "magnifyingglass") {
                    router.openCommunitySearch()
                }
                .accessibilityHint("Search Community posts")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Calendar", systemImage: "calendar") {
                    router.openCommunityCalendar()
                }
                .accessibilityHint("Open calendar from Community")
            }
        }
        .sheet(item: $createViewModel, onDismiss: {
            feedViewModel?.reload()
            savedViewModel?.reload()
        }) { viewModel in
            CommunityCreatePostSheet(viewModel: viewModel)
        }
        .task {
            ensureViewModels()
        }
        .onChange(of: selectedTab) { _, newTab in
            switch newTab {
            case .feed:
                feedViewModel?.reload()
            case .saved:
                savedViewModel?.reload()
            case .discover:
                break
            }
        }
    }

    private func ensureViewModels() {
        if feedViewModel == nil {
            feedViewModel = CommunityFeedViewModel(client: communityClient, mode: .feed)
            feedViewModel?.reload()
        }
        if savedViewModel == nil {
            savedViewModel = CommunityFeedViewModel(client: communityClient, mode: .saved)
        }
    }

    private func presentCreatePost() {
        ensureViewModels()
        createViewModel = CreateCommunityPostViewModel(client: communityClient) { _ in
            feedViewModel?.reload()
        }
    }
}

// MARK: - Hub content

private struct CommunityHubContent: View {
    @Binding var selectedTab: CommunityHubTab
    var feedViewModel: CommunityFeedViewModel
    var savedViewModel: CommunityFeedViewModel
    var onCreatePost: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Connect, share, and celebrate progress together.")
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PluriSpacing.lg)
                .padding(.top, PluriSpacing.sm)

            CommunityHubTabPicker(selectedTab: $selectedTab)
                .padding(.horizontal, PluriSpacing.lg)
                .padding(.vertical, PluriSpacing.md)

            switch selectedTab {
            case .feed:
                CommunityFeedView(viewModel: feedViewModel, onCreatePost: onCreatePost)
            case .discover:
                CommunityDiscoverView()
            case .saved:
                CommunitySavedView(viewModel: savedViewModel)
            }
        }
    }
}

// MARK: - Create post sheet

/// Loads Share Workout snapshots after the composer is on screen so a SwiftData
/// fault cannot blank the Community tab (BUG-001).
private struct CommunityCreatePostSheet: View {
    @Environment(PlanStore.self) private var planStore
    @Environment(SwiftDataWorkoutSessionRepository.self) private var workoutSessionRepository
    @Bindable var viewModel: CreateCommunityPostViewModel

    var body: some View {
        CreateCommunityPostView(viewModel: viewModel)
            .task {
                guard viewModel.availableSnapshots.isEmpty else { return }
                viewModel.availableSnapshots = CommunityWorkoutSnapshotLoader.recentSnapshots(
                    from: workoutSessionRepository,
                    planStore: planStore
                )
            }
    }
}

// MARK: - Tab picker

private struct CommunityHubTabPicker: View {
    @Binding var selectedTab: CommunityHubTab

    var body: some View {
        HStack(spacing: PluriSpacing.sm) {
            ForEach(CommunityHubTab.allCases) { tab in
                PluriChip(
                    title: LocalizedStringKey(tab.title),
                    isSelected: tab == selectedTab
                ) {
                    selectedTab = tab
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Community tabs")
    }
}

#Preview("Hub populated") {
    let container = try! ModelContainer(
        for: Schema([
            WorkoutSessionRecord.self,
            SetLogRecord.self,
        ]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    NavigationStack {
        CommunityView()
    }
    .environment(MainRouter())
    .environment(\.communityClient, MockCommunityClient())
    .environment(PlanStore(mutationService: MockPlanMutationService()))
    .environment(SwiftDataWorkoutSessionRepository(modelContext: container.mainContext))
    .modelContainer(container)
    .background(PluriColor.bgCanvas)
}
