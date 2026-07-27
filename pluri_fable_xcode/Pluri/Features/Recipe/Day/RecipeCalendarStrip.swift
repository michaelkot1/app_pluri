import SwiftUI

/// Horizontal day strip for Recipe Day (M7-08 / SPEC §12): Home calendar
/// spirit without workout dots. Tapping a day selects it; opens centered on
/// the selected day.
struct RecipeCalendarStrip: View {
    var days: [Date]
    var selectedDay: Date
    var today: Date
    var calendar: Calendar = .current
    var onSelect: (Date) -> Void

    @State private var position = ScrollPosition(idType: Date.self)

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: PluriSpacing.sm) {
                ForEach(days, id: \.self) { day in
                    RecipeCalendarDayCell(
                        day: day,
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                        isToday: calendar.isDate(day, inSameDayAs: today)
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
        .accessibilityLabel("Recipe day picker")
    }
}

private struct RecipeCalendarDayCell: View {
    var day: Date
    var isSelected: Bool
    var isToday: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: PluriSpacing.xs) {
                Text(day, format: .dateTime.weekday(.abbreviated))
                    .font(PluriFont.overline)
                    .textCase(.uppercase)
                    .foregroundStyle(isSelected ? PluriColor.accentPink : PluriColor.textSecondary)

                Text(day, format: .dateTime.day())
                    .font(PluriFont.metricValue)
                    .monospacedDigit()
                    .foregroundStyle(numeralForeground)
                    .frame(width: 44, height: 44)
                    .background(numeralBackground, in: .circle)
                    .overlay {
                        if isToday, !isSelected {
                            Circle().strokeBorder(PluriColor.accentPink, lineWidth: 1.5)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var numeralForeground: Color {
        isSelected ? .white : PluriColor.textPrimary
    }

    private var numeralBackground: Color {
        isSelected ? PluriColor.accentPink : PluriColor.bgSurface
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let days = (0..<14).compactMap { calendar.date(byAdding: .day, value: $0 - 3, to: today) }

    return RecipeCalendarStrip(
        days: days,
        selectedDay: today,
        today: today,
        onSelect: { _ in }
    )
    .padding(PluriSpacing.lg)
    .background(PluriColor.bgCanvas)
}
