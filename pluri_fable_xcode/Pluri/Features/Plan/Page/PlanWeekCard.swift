import SwiftUI

/// One week's card on the Plan page (M3-10 / SPEC §6): week number, workout
/// count, a "week complete" note when everything is finished, and each
/// workout's name, day, duration, type color, and completion checkmark.
/// Tapping the card opens Week Overview (§6.3).
struct PlanWeekCard: View {
    var week: PlanWeek
    var stats: PlanStore.CompletionStats
    var viewModel: PlanViewModel
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            PluriCard {
                VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Week \(week.number)")
                            .font(PluriFont.sectionHeader)
                            .foregroundStyle(PluriColor.textPrimary)
                        Spacer()
                        Text(viewModel.workoutCountLabel(for: week))
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textSecondary)
                    }

                    if stats.isFullyFinished {
                        Label("Week complete", systemImage: "checkmark.circle.fill")
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.statusGreen)
                    }

                    ForEach(week.sessions) { session in
                        PlanSessionRow(session: session, viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the Week \(week.number) overview")
    }
}
