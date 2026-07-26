import SwiftUI

/// Insights calendar day filter (M5-13 / SPEC §14 #62).
///
/// Graphical day picker in the spirit of `CalendarDayPickerSheet` / Home day
/// selection — filters the Workouts list; does **not** open plan rearrange
/// (`MainRouter.openCalendar()`).
struct InsightsDayFilterSheet: View {
    var initialDate: Date
    var onConfirm: (Date) -> Void
    var onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date

    init(
        initialDate: Date = .now,
        onConfirm: @escaping (Date) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.initialDate = initialDate
        self.onConfirm = onConfirm
        self.onClear = onClear
        _selectedDate = State(initialValue: initialDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                Text("Filter by day")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                Text("Show workouts performed on a single day. Multi-day ranges arrive later.")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)

                DatePicker(
                    "Day",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(PluriColor.brandOrange)
                .accessibilityLabel("Day to filter")

                Button("Show this day") {
                    onConfirm(selectedDate)
                    dismiss()
                }
                .buttonStyle(.pluriPrimary)
                .frame(minHeight: 44)

                Button("Clear filter") {
                    onClear()
                    dismiss()
                }
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.brandOrange)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(PluriSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(PluriRadius.xl)
        .presentationBackground(PluriColor.bgSurface)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            InsightsDayFilterSheet(
                onConfirm: { _ in },
                onClear: {}
            )
        }
}
