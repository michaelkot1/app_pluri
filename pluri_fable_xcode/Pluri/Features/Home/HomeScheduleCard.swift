import SwiftUI

/// Calendar and planned activity presented as one cohesive surface.
struct HomeScheduleCard: View {
    var summary: HomeMonthSummary
    var days: [Date]
    var selectedDay: Date
    var today: Date
    var sessionsByDay: [Date: [PlannedSession]]
    var selectedSessions: [PlannedSession]
    var flexibleSessions: [PlannedSession]
    var onSelectDay: (Date) -> Void
    var onViewCalendar: () -> Void

    var body: some View {
        PluriCard {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                HomeScheduleHeader(
                    summary: summary,
                    onViewCalendar: onViewCalendar
                )

                HomeCalendarStrip(
                    days: days,
                    selectedDay: selectedDay,
                    today: today,
                    sessionsByDay: sessionsByDay,
                    onSelect: onSelectDay
                )

                Divider()
                    .overlay(PluriColor.lineDivider)

                HomeSelectedDayCard(
                    day: selectedDay,
                    isToday: Calendar.current.isDate(selectedDay, inSameDayAs: today),
                    sessions: selectedSessions
                )

                if !flexibleSessions.isEmpty {
                    Divider()
                        .overlay(PluriColor.lineDivider)
                    HomeFlexibleSessions(sessions: flexibleSessions)
                }
            }
        }
    }
}

private struct HomeScheduleHeader: View {
    var summary: HomeMonthSummary
    var onViewCalendar: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                Text(summary.title)
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)
                if let completionText = summary.completionText {
                    Text(completionText)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                }
            }

            Spacer()

            Button("View calendar", systemImage: "calendar", action: onViewCalendar)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.brandOrangeDeep)
                .frame(minHeight: 44)
        }
    }
}

private struct HomeFlexibleSessions: View {
    var sessions: [PlannedSession]

    @Environment(MainRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text("Anytime this week")
                .font(PluriFont.overline)
                .textCase(.uppercase)
                .kerning(1)
                .foregroundStyle(PluriColor.textSecondary)

            ForEach(sessions) { session in
                Button {
                    router.openWorkoutDetail(sessionID: session.id)
                } label: {
                    HomeSessionRow(session: session)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the workout details")
            }
        }
    }
}
