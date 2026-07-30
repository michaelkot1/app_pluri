import SwiftUI

/// The real Plan page (M3-10 / SPEC §6): plan card with goal, end date, and
/// the weeks-completed tracker; the circular action-button row; and one
/// accessible card per week. Observes the shared `PlanStore` (M3-04) and
/// navigates through the `MainRouter`'s typed Plan path.
struct PlanView: View {
    @Environment(PlanStore.self) private var planStore

    @State private var viewModel = PlanViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                switch planStore.loadState {
                case .loading:
                    PlanLoadingIndicator()
                case .failed:
                    HomeMessageCard(
                        title: "We couldn't load your plan",
                        message: "Check your connection and relaunch — your plan is safe on your account."
                    )
                case .empty:
                    HomeMessageCard(
                        title: "No active plan yet",
                        message: "We couldn't find an active plan on your account. Plan tools arrive with the next update."
                    )
                case .ready:
                    if let plan = planStore.plan {
                        PlanPageContent(plan: plan, viewModel: viewModel)
                    }
                }
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .background(PluriColor.bgCanvas)
        .navigationTitle("Plan")
    }
}

/// Plan card + action buttons + week cards for the ready state.
private struct PlanPageContent: View {
    var plan: GeneratedPlan
    var viewModel: PlanViewModel

    @Environment(PlanStore.self) private var planStore
    @Environment(MainRouter.self) private var router

    var body: some View {
        PlanCardView(
            model: viewModel.cardModel(for: plan, completedWeekCount: planStore.completedWeekCount)
        )

        PlanActionButtonsRow()

        ForEach(plan.weeks) { week in
            PlanWeekCard(
                week: week,
                stats: planStore.completionStats(forWeek: week.number),
                viewModel: viewModel
            ) {
                router.openWeekOverview(weekID: week.id)
            }
        }
    }
}

/// Centered spinner while the router is still resolving plan content.
private struct PlanLoadingIndicator: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView("Loading your plan…")
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
            Spacer()
        }
        .padding(.vertical, PluriSpacing.xl)
    }
}

#if DEBUG
#Preview("Ready") {
    NavigationStack {
        PlanView()
    }
    .environment(HomePreviewData.readyStore())
    .environment(MainRouter())
}

#Preview("Flexible") {
    NavigationStack {
        PlanView()
    }
    .environment(HomePreviewData.flexibleStore())
    .environment(MainRouter())
}

#Preview("Empty") {
    NavigationStack {
        PlanView()
    }
    .environment(HomePreviewData.emptyStore())
    .environment(MainRouter())
}

#Preview("Failed") {
    NavigationStack {
        PlanView()
    }
    .environment(HomePreviewData.failedStore())
    .environment(MainRouter())
}
#endif
