import SwiftUI

/// Bottom sheet for picking a target day inside the plan window (M3-13):
/// used both to move a dated workout and to assign a flexible one to a day.
/// The caller runs the mutation; a returned message keeps the sheet open
/// with gentle inline feedback instead of dismissing on failure.
struct CalendarDayPickerSheet: View {
    var workoutTitle: String
    /// The plan's start…end window — days outside it aren't selectable.
    var range: ClosedRange<Date>
    var initialDate: Date
    var confirmTitle: String
    /// Runs the mutation; returns `nil` on success (the sheet dismisses)
    /// or a gentle message to show inline.
    var onConfirm: (Date) async -> String?

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date
    @State private var feedback: String?
    @State private var isSaving = false

    init(
        workoutTitle: String,
        range: ClosedRange<Date>,
        initialDate: Date,
        confirmTitle: String,
        onConfirm: @escaping (Date) async -> String?
    ) {
        self.workoutTitle = workoutTitle
        self.range = range
        self.initialDate = initialDate
        self.confirmTitle = confirmTitle
        self.onConfirm = onConfirm
        _selectedDate = State(initialValue: min(max(initialDate, range.lowerBound), range.upperBound))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                Text(workoutTitle)
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                Text("Pick a day within your plan. Each day holds one workout.")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)

                DatePicker(
                    "Day",
                    selection: $selectedDate,
                    in: range,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(PluriColor.brandOrange)

                if let feedback {
                    Text(feedback)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                }

                Button(confirmTitle) {
                    Task { await confirm() }
                }
                .buttonStyle(.pluriPrimary)
                .disabled(isSaving)
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

    private func confirm() async {
        isSaving = true
        feedback = nil
        let message = await onConfirm(selectedDate)
        isSaving = false
        if let message {
            feedback = message
        } else {
            dismiss()
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            CalendarDayPickerSheet(
                workoutTitle: "Upper Body Push",
                range: Date.now...(Calendar.current.date(byAdding: .day, value: 13, to: .now) ?? .now),
                initialDate: .now,
                confirmTitle: "Move here",
                onConfirm: { _ in nil }
            )
        }
}
