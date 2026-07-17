import SwiftUI

/// The selected day's workout content below the calendar strip (M3-07 /
/// SPEC §5): each session's title, type, duration, and status — or a gentle
/// empty state, never a fake workout.
struct HomeSelectedDayCard: View {
    var day: Date
    var isToday: Bool
    var sessions: [PlannedSession]

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                Text(dayTitle)
                    .font(PluriFont.overline)
                    .textCase(.uppercase)
                    .kerning(1)
                    .foregroundStyle(PluriColor.textSecondary)

                if sessions.isEmpty {
                    Text("Nothing scheduled — rest is part of the plan too.")
                        .font(PluriFont.body)
                        .foregroundStyle(PluriColor.textSecondary)
                } else {
                    ForEach(sessions) { session in
                        HomeSessionRow(session: session)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dayTitle: String {
        isToday ? "Today" : day.formatted(date: .abbreviated, time: .omitted)
    }
}

/// One workout line: color bar, title, type + duration, status mark.
private struct HomeSessionRow: View {
    var session: PlannedSession

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
                Text("\(session.workoutType.title) · \(durationText)")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)
            }

            Spacer(minLength: PluriSpacing.sm)

            HomeSessionStatusMark(status: session.status)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var durationText: String {
        Duration.seconds(session.durationMinutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

/// Status glyph: checkmark when completed, a quiet skip mark when skipped,
/// nothing while still scheduled.
private struct HomeSessionStatusMark: View {
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

#Preview {
    VStack(spacing: PluriSpacing.md) {
        HomeSelectedDayCard(day: .now, isToday: true, sessions: [])
    }
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
