import SwiftUI

/// Bottom sheet for adding a workout to an empty day (M3-13 / SPEC §14 #38):
/// the user picks any existing plan workout as the source, and a clone (new
/// IDs, `scheduled`) lands on the chosen day. Failure keeps the sheet open
/// with gentle inline feedback.
struct CalendarSourcePickerSheet: View {
    var date: Date
    /// Every plan workout, offered as a source to clone.
    var sources: [PlannedSession]
    /// Runs the clone-add; returns `nil` on success (the sheet dismisses)
    /// or a gentle message to show inline.
    var onConfirm: (UUID) async -> String?

    @Environment(\.dismiss) private var dismiss

    @State private var feedback: String?
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                Text("Add a workout")
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                Text("Pick a workout from your plan to repeat on \(date.formatted(date: .abbreviated, time: .omitted)).")
                    .font(PluriFont.label)
                    .foregroundStyle(PluriColor.textSecondary)

                if let feedback {
                    Text(feedback)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                }

                ForEach(sources) { source in
                    CalendarSourceOptionRow(source: source) {
                        Task { await confirm(sourceID: source.id) }
                    }
                    .disabled(isSaving)
                }
            }
            .padding(PluriSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(PluriRadius.xl)
        .presentationBackground(PluriColor.bgSurface)
    }

    private func confirm(sourceID: UUID) async {
        isSaving = true
        feedback = nil
        let message = await onConfirm(sourceID)
        isSaving = false
        if let message {
            feedback = message
        } else {
            dismiss()
        }
    }
}

/// One selectable source workout: color bar, title, and type + duration.
private struct CalendarSourceOptionRow: View {
    var source: PlannedSession
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            PluriCard {
                HStack(spacing: PluriSpacing.sm) {
                    RoundedRectangle(cornerRadius: PluriRadius.sm)
                        .fill(WorkoutColorResolver.token(for: source).color)
                        .frame(width: 4)

                    VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                        Text(source.title)
                            .font(PluriFont.body)
                            .foregroundStyle(PluriColor.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text("\(source.workoutType.title) · \(durationText)")
                            .font(PluriFont.label)
                            .foregroundStyle(PluriColor.textSecondary)
                    }

                    Spacer(minLength: PluriSpacing.sm)

                    Image(systemName: "plus.circle")
                        .foregroundStyle(PluriColor.brandOrange)
                        .accessibilityHidden(true)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Adds a copy of this workout")
    }

    private var durationText: String {
        Duration.seconds(source.durationMinutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            CalendarSourcePickerSheet(
                date: .now,
                sources: [],
                onConfirm: { _ in nil }
            )
        }
}
