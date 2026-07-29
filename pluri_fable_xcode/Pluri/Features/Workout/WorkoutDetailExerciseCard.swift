import SwiftUI

/// One self-contained exercise block in the workout overview.
struct WorkoutDetailExerciseCard: View {
    let exercise: PlannedExercise
    let number: Int
    let workoutColor: Color

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Exercise \(number)")
                    .font(PluriFont.label)
                    .bold()
                    .foregroundStyle(.white)
                Spacer()
                Text(exercise.equipment)
                    .font(PluriFont.label)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, PluriSpacing.md)
            .frame(minHeight: 36)
            .background(workoutColor)

            HStack(alignment: .center, spacing: PluriSpacing.md) {
                Text(number.formatted())
                    .font(.title2.bold())
                    .foregroundStyle(PluriColor.textSecondary)
                    .frame(width: 34)

                Rectangle()
                    .fill(PluriColor.bgMuted)
                    .frame(width: 2, height: 56)

                VStack(alignment: .leading, spacing: PluriSpacing.xs) {
                    Text(exercise.name)
                        .font(PluriFont.body)
                        .bold()
                        .foregroundStyle(PluriColor.textPrimary)

                    Text(exercise.setsRepsSummary)
                        .font(PluriFont.label)
                        .foregroundStyle(PluriColor.textSecondary)
                        .monospacedDigit()
                }

                Spacer(minLength: PluriSpacing.sm)

                Text("\(exercise.sets) sets")
                    .font(PluriFont.label)
                    .bold()
                    .foregroundStyle(PluriColor.textSecondary)
            }
            .padding(PluriSpacing.md)
        }
        .background(PluriColor.bgSurface)
        .clipShape(.rect(cornerRadius: PluriRadius.md))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Exercise \(number), \(exercise.name), \(exercise.setsRepsSummary), \(exercise.equipment)"
        )
    }
}
