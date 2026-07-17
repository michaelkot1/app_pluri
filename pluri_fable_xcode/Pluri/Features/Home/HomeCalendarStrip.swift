import SwiftUI

/// Horizontal day strip for the visible month (M3-07 / SPEC §5): one workout
/// dot per day that has a dated session (SPEC §14 #37), tinted by the
/// workout's resolved color. Tapping a day selects it; the strip opens
/// centered on the selected day.
struct HomeCalendarStrip: View {
    var days: [Date]
    var selectedDay: Date
    var today: Date
    var sessionsByDay: [Date: [PlannedSession]]
    var calendar: Calendar = .current
    var onSelect: (Date) -> Void

    @State private var position = ScrollPosition(idType: Date.self)

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: PluriSpacing.sm) {
                ForEach(days, id: \.self) { day in
                    HomeCalendarDayCell(
                        day: day,
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                        isToday: calendar.isDate(day, inSameDayAs: today),
                        dotColor: dotColor(for: day)
                    ) {
                        onSelect(day)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onAppear {
            position.scrollTo(id: calendar.startOfDay(for: selectedDay), anchor: .center)
        }
    }

    /// One dot per day in v1 (SPEC §5); the first session's color wins.
    private func dotColor(for day: Date) -> Color? {
        guard let first = sessionsByDay[calendar.startOfDay(for: day)]?.first else { return nil }
        return WorkoutColorResolver.token(for: first).color
    }
}

/// One tappable day: weekday abbreviation, day numeral, and the workout dot.
private struct HomeCalendarDayCell: View {
    var day: Date
    var isSelected: Bool
    var isToday: Bool
    var dotColor: Color?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: PluriSpacing.xs) {
                Text(day, format: .dateTime.weekday(.abbreviated))
                    .font(PluriFont.overline)
                    .textCase(.uppercase)
                    .foregroundStyle(isSelected ? PluriColor.brandOrange : PluriColor.textSecondary)

                Text(day, format: .dateTime.day())
                    .font(PluriFont.metricValue)
                    .monospacedDigit()
                    .foregroundStyle(numeralForeground)
                    .frame(width: 44, height: 44)
                    .background(numeralBackground, in: .circle)
                    .overlay {
                        if isToday, !isSelected {
                            Circle().strokeBorder(PluriColor.brandOrange, lineWidth: 1.5)
                        }
                    }

                Circle()
                    .fill(dotColor ?? .clear)
                    .frame(width: 6, height: 6)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityValue(dotColor == nil ? "No workout" : "Has a workout")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var numeralForeground: Color {
        isSelected ? .white : PluriColor.textPrimary
    }

    private var numeralBackground: Color {
        isSelected ? PluriColor.brandOrange : PluriColor.bgSurface
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let days = (0..<14).compactMap { calendar.date(byAdding: .day, value: $0 - 3, to: today) }

    return HomeCalendarStrip(
        days: days,
        selectedDay: today,
        today: today,
        sessionsByDay: [:],
        onSelect: { _ in }
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
