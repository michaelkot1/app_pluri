import SwiftUI

/// Plan-teaser summary (M1-18): the headline facts about the generated plan —
/// goal, length, cadence, duration, and dates (SPEC §6 Plan card fields).
struct PlanSummaryCard: View {
    var plan: GeneratedPlan

    private var durationText: String {
        Duration.seconds(plan.sessionDurationMinutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private var cadenceText: String {
        plan.scheduleType == .scheduled ? "on set days" : "any days you like"
    }

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                Text(plan.goal.title)
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                HStack(spacing: PluriSpacing.md) {
                    PlanStatBadge(value: "\(plan.weekCount)", label: plan.weekCount == 1 ? "week" : "weeks")
                    PlanStatBadge(value: "\(plan.sessionsPerWeek)", label: "per week")
                    PlanStatBadge(value: durationText, label: "each")
                }

                VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                    PlanSummaryRow(
                        icon: "calendar",
                        text: "Starts \(plan.startDate.formatted(date: .abbreviated, time: .omitted))"
                    )
                    PlanSummaryRow(
                        icon: "flag.checkered",
                        text: "Ends \(plan.endDate.formatted(date: .abbreviated, time: .omitted))"
                    )
                    PlanSummaryRow(
                        icon: "figure.run",
                        text: "\(plan.totalSessions) workouts total, \(cadenceText)"
                    )
                }
            }
        }
    }
}

/// A small stat pill (e.g. "6 weeks") used inside `PlanSummaryCard`.
private struct PlanStatBadge: View {
    var value: String
    var label: String

    var body: some View {
        VStack(spacing: PluriSpacing.xs) {
            Text(value)
                .font(PluriFont.metricValue)
                .foregroundStyle(PluriColor.brandOrange)
            Text(label)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PluriSpacing.sm)
        .background(PluriColor.bgMuted, in: .rect(cornerRadius: PluriRadius.md))
    }
}

/// An icon + text line used inside `PlanSummaryCard`.
private struct PlanSummaryRow: View {
    var icon: String
    var text: String

    var body: some View {
        Label {
            Text(text)
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(PluriColor.brandOrange)
        }
    }
}
