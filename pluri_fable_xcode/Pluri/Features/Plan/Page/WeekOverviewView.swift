import SwiftUI

/// Week Overview (M3-11 / SPEC §6.3): the selected week's complete schedule
/// as a larger view of its Plan-page card. Selecting a workout routes to the
/// honest Workout Detail stub owned by M4 — no workout execution here.
struct WeekOverviewView: View {
    var week: PlanWeek

    @Environment(PlanStore.self) private var planStore
    @Environment(MainRouter.self) private var router

    @State private var viewModel = PlanViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                WeekOverviewSummary(
                    week: week,
                    stats: planStore.completionStats(forWeek: week.number),
                    viewModel: viewModel
                )

                ForEach(week.sessions) { session in
                    Button {
                        router.openPlanWorkoutDetail(sessionID: session.id)
                    } label: {
                        PluriCard {
                            HStack(spacing: PluriSpacing.sm) {
                                PlanSessionRow(session: session, viewModel: viewModel)
                                Image(systemName: "chevron.right")
                                    .font(PluriFont.label)
                                    .foregroundStyle(PluriColor.textTertiary)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the workout details")
                }
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .background(PluriColor.bgCanvas)
        .navigationTitle("Week \(week.number)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Header card: workout count and how much of the week is done.
private struct WeekOverviewSummary: View {
    var week: PlanWeek
    var stats: PlanStore.CompletionStats
    var viewModel: PlanViewModel

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                Text(viewModel.workoutCountLabel(for: week))
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)
                Text(completionText)
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var completionText: String {
        if stats.isFullyFinished {
            "Week complete"
        } else {
            "\(stats.completed) of \(stats.total) done"
        }
    }
}

#if DEBUG
#Preview("Scheduled week") {
    let store = HomePreviewData.readyStore()
    let week = store.plan?.weeks.first ?? PlanWeek(number: 1, sessions: [])
    NavigationStack {
        WeekOverviewView(week: week)
    }
    .environment(store)
    .environment(MainRouter())
}

#Preview("Flexible week") {
    let store = HomePreviewData.flexibleStore()
    let week = store.plan?.weeks.first ?? PlanWeek(number: 1, sessions: [])
    NavigationStack {
        WeekOverviewView(week: week)
    }
    .environment(store)
    .environment(MainRouter())
}
#endif
