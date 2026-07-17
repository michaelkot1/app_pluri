import SwiftUI

/// The Plan page's top card (M3-10 / SPEC §6): goal/plan name, plan end
/// date, and the "Weeks Completed 1/6" tracker with a progress bar.
/// (Named apart from `PlanSummaryCard`, the M1-18 plan-ready teaser.)
struct PlanCardView: View {
    var model: PlanCardModel

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text(model.title)
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                Text("Ends \(model.endDateText)")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)

                VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                    HStack {
                        Text("Weeks Completed")
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textSecondary)
                        Spacer()
                        Text(model.trackerText)
                            .font(PluriFont.metricValue)
                            .foregroundStyle(PluriColor.textPrimary)
                    }
                    PluriProgressBar(value: model.progress)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(model.title), ends \(model.endDateText), \(model.completedWeeks) of \(model.totalWeeks) weeks completed"
        )
    }
}

#Preview {
    PlanCardView(
        model: PlanCardModel(
            title: "Build muscle",
            endDateText: Date.now.formatted(date: .abbreviated, time: .omitted),
            completedWeeks: 1,
            totalWeeks: 6
        )
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
