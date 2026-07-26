import SwiftUI

/// Expanded exercise sheet (M4-08 / SPEC §8): longer description, per-exercise
/// notes, cached media. Video toggle is hidden when `videoURL` is nil
/// (SPEC §14 #11).
struct WorkoutExerciseDetailSheet: View {
    var exercise: PlannedExercise
    var descriptionText: String
    var videoURL: URL?
    @Binding var notesDraft: String
    var errorMessage: String?
    var onSaveNotes: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.md) {
                Text(exercise.name)
                    .font(PluriFont.sectionHeader)
                    .foregroundStyle(PluriColor.textPrimary)

                CachedExerciseMediaView(remoteURL: exercise.imageURL)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(.rect(cornerRadius: PluriRadius.lg))
                    .accessibilityLabel("\(exercise.name) demonstration")

                // Image ↔ video toggle intentionally omitted while `videoURL`
                // is nil (SPEC §14 #11). Parameter retained for a future source.

                metaRow

                if descriptionText.isEmpty {
                    Text("A longer description isn’t in the catalog yet for this exercise.")
                        .font(PluriFont.body)
                        .foregroundStyle(PluriColor.textSecondary)
                } else {
                    Text(descriptionText)
                        .font(PluriFont.body)
                        .foregroundStyle(PluriColor.textPrimary)
                }

                VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                    Text("Exercise notes")
                        .font(PluriFont.overline)
                        .textCase(.uppercase)
                        .kerning(1)
                        .foregroundStyle(PluriColor.textSecondary)

                    TextEditor(text: $notesDraft)
                        .font(PluriFont.body)
                        .foregroundStyle(PluriColor.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(PluriSpacing.sm)
                        .frame(minHeight: 120)
                        .background(PluriColor.bgMuted, in: .rect(cornerRadius: PluriRadius.md))
                        .accessibilityLabel("Exercise notes")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.statusRedSoft)
                }

                Button("Save notes", action: onSaveNotes)
                    .buttonStyle(.pluriPrimary)
            }
            .padding(PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PluriColor.bgSurface)
        // Video toggle stays hidden while `videoURL` is nil (§14 #11); id notes readiness.
        .accessibilityIdentifier(videoURL == nil ? "exercise-sheet-image-only" : "exercise-sheet-has-video")
    }

    private var metaRow: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.xs) {
            Text(exercise.equipment)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
            Text(muscleLine)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textTertiary)
            Text(exercise.setsRepsSummary)
                .font(PluriFont.label)
                .foregroundStyle(PluriColor.textSecondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var muscleLine: String {
        if exercise.secondaryMuscles.isEmpty {
            return exercise.targetMuscle
        }
        let secondary = exercise.secondaryMuscles.joined(separator: ", ")
        return "\(exercise.targetMuscle) · \(secondary)"
    }
}

#if DEBUG
#Preview {
    @Previewable @State var notes = ""
    WorkoutExerciseDetailSheet(
        exercise: PlannedExercise(
            exerciseID: "0001",
            name: "Barbell Bench Press",
            bodyPart: "Chest",
            equipment: "Barbell",
            targetMuscle: "Pectorals",
            secondaryMuscles: ["Triceps"],
            imageURL: nil,
            order: 0,
            sets: 3,
            reps: 10
        ),
        descriptionText: "Lie on a flat bench and press the bar from chest to lockout.",
        videoURL: nil,
        notesDraft: $notes,
        errorMessage: nil,
        onSaveNotes: {}
    )
}
#endif
