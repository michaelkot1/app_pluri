import SwiftUI

/// Exercise list for the Workout Screen (M4-07/10).
///
/// Lazy on purpose: every mounted card holds a cached GIF in a `UIImageView`,
/// so building all of them up front made a long session expensive to render
/// and to keep animating (SPEC §14 #76).
struct WorkoutExerciseListView: View {
    var session: PlannedSession
    var viewModel: WorkoutScreenViewModel
    var usesImperialUnits: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
            Text("Exercises")
                .font(PluriFont.overline)
                .textCase(.uppercase)
                .kerning(1)
                .foregroundStyle(PluriColor.textSecondary)

            LazyVStack(alignment: .leading, spacing: PluriSpacing.sm) {
                ForEach(session.exercises) { exercise in
                    WorkoutExerciseCardView(
                        exercise: exercise,
                        mediaURL: viewModel.resolvedImageURL(for: exercise),
                        showsInlineLog: viewModel.showsLiveControls,
                        usesImperialUnits: usesImperialUnits,
                        loggedSetCount: viewModel.loggedSetCountByExercise[exercise.id] ?? 0,
                        action: {
                            viewModel.selectExercise(exercise.id)
                        },
                        onLogSet: { reps, weight in
                            viewModel.logSet(
                                exercise: exercise,
                                reps: reps,
                                weightDisplay: weight
                            )
                        },
                        onLogDuration: { seconds in
                            viewModel.logSet(
                                exercise: exercise,
                                reps: 0,
                                weightDisplay: nil,
                                durationSeconds: seconds
                            )
                        }
                    )
                }
            }
        }
    }
}
