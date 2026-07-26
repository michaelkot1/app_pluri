import SwiftUI

/// Honest completion stub until M4-12 ships Discard / Save / summary fields.
struct WorkoutCompletionStubView: View {
    var workoutName: String
    var elapsedSeconds: Int

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.lg) {
            Text("Summary arrives next")
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textPrimary)

            Text(workoutName)
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textPrimary)

            Text(WorkoutScreenViewModel.formatElapsed(elapsedSeconds))
                .font(PluriFont.sectionHeader)
                .foregroundStyle(PluriColor.textSecondary)
                .monospacedDigit()
                .accessibilityLabel(
                    "Elapsed time, \(WorkoutScreenViewModel.formatElapsed(elapsedSeconds))"
                )

            Text("Discard, Save, and full summary details land in a later update.")
                .font(PluriFont.body)
                .foregroundStyle(PluriColor.textSecondary)

            Spacer(minLength: 0)
        }
        .padding(PluriSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PluriColor.bgCanvas)
        .navigationTitle("Workout complete")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        WorkoutCompletionStubView(workoutName: "Push", elapsedSeconds: 1_245)
    }
}
#endif
