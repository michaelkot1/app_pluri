import SwiftUI

/// One workout line on a Plan week card or the Week Overview (M3-10/11 /
/// SPEC §6): type color bar, title, day + type + duration, and a checkmark
/// when completed. Color is supplementary — the type name and completion
/// state are always spelled out in text/labels.
struct PlanSessionRow: View {
    var session: PlannedSession
    var viewModel: PlanViewModel

    var body: some View {
        HStack(spacing: PluriSpacing.sm) {
            RoundedRectangle(cornerRadius: PluriRadius.sm)
                .fill(WorkoutColorResolver.token(for: session).color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                Text(session.title)
                    .font(PluriFont.body)
                    .foregroundStyle(PluriColor.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(viewModel.dayLabel(for: session)) · \(session.workoutType.title) · \(viewModel.durationLabel(for: session))")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: PluriSpacing.sm)

            PlanSessionStatusMark(status: session.status)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// Status glyph: checkmark when completed, a quiet skip mark when skipped,
/// nothing while still scheduled — same vocabulary as Home's day card.
private struct PlanSessionStatusMark: View {
    var status: WorkoutStatus

    var body: some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PluriColor.statusGreen)
                .accessibilityLabel("Completed")
        case .skipped:
            Image(systemName: "arrow.uturn.forward.circle")
                .foregroundStyle(PluriColor.textTertiary)
                .accessibilityLabel("Skipped")
        case .scheduled:
            EmptyView()
        }
    }
}
