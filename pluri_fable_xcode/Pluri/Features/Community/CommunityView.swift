import SwiftData
import SwiftUI

/// Community root shell (M8-05…M8-12): Feed · Discover · Saved hub chrome,
/// search + calendar on the Community stack, create-post sheet.
struct CommunityView: View {
    @Environment(MainRouter.self) private var router
    @Environment(\.communityClient) private var communityClient
    @Environment(PlanStore.self) private var planStore
    @Environment(SwiftDataWorkoutSessionRepository.self) private var workoutSessionRepository

    @State private var selectedTab: CommunityHubTab = .feed
    @State private var feedViewModel: CommunityFeedViewModel?
    @State private var savedViewModel: CommunityFeedViewModel?
    @State private var createViewModel: CreateCommunityPostViewModel?
    @State private var showsCreatePost = false

    var body: some View {
        Group {
            if let feedViewModel, let savedViewModel {
                tabContent(feedViewModel: feedViewModel, savedViewModel: savedViewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .sheet(isPresented: $showsCreatePost, onDismiss: {
            createViewModel = nil
            feedViewModel?.reload()
            savedViewModel?.reload()
        }) {
            if let createViewModel {
                CreateCommunityPostView(viewModel: createViewModel)
            }
        }
        .onAppear {
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

    @ViewBuilder
    private func tabContent(
        feedViewModel: CommunityFeedViewModel,
        savedViewModel: CommunityFeedViewModel
    ) -> some View {
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
                CommunityFeedView(viewModel: feedViewModel) {
                    presentCreatePost()
                }
            case .discover:
                CommunityDiscoverView()
            case .saved:
                CommunitySavedView(viewModel: savedViewModel)
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
        let snapshots = recentWorkoutSnapshots()
        createViewModel = CreateCommunityPostViewModel(
            client: communityClient,
            availableSnapshots: snapshots
        ) { _ in
            feedViewModel?.reload()
        }
        showsCreatePost = true
    }

    private func recentWorkoutSnapshots() -> [WorkoutSnapshot] {
        let sessions: [WorkoutSessionRecord]
        do {
            sessions = try workoutSessionRepository.fetchAllCompletedSessions()
        } catch {
            return []
        }

        let titlesByPlanID: [UUID: String] = {
            guard let plan = planStore.plan else { return [:] }
            var map: [UUID: String] = [:]
            for week in plan.weeks {
                for session in week.sessions {
                    map[session.id] = session.title
                }
            }
            return map
        }()

        return sessions
            .sorted { ($0.endedAt ?? $0.startedAt) > ($1.endedAt ?? $1.startedAt) }
            .prefix(12)
            .map { session in
                let title = session.planWorkoutId.flatMap { titlesByPlanID[$0] }
                return WorkoutSnapshot.from(session: session, title: title)
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
