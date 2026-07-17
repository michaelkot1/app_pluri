import SwiftUI

/// Honest Workout Detail stub (M3-06/M3-09): shows the chosen session's
/// headline facts and says plainly that the full detail page — exercises,
/// sets, and starting the workout — arrives in M4. No workout execution here.
struct WorkoutDetailStubView: View {
    /// The session being previewed; `nil` when it can't be found in the plan.
    var session: PlannedSession?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PluriSpacing.lg) {
                if let session {
                    PluriCard {
                        VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                            Text(session.title)
                                .font(PluriFont.sectionHeader)
                                .foregroundStyle(PluriColor.textPrimary)
                            Text("\(session.workoutType.title) · \(durationText(for: session)) · \(session.exercises.count) exercises")
                                .font(PluriFont.label)
                                .foregroundStyle(PluriColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                PluriCard {
                    VStack(alignment: .leading, spacing: PluriSpacing.sm) {
                        Text("Workout details are on their way")
                            .font(PluriFont.sectionHeader)
                            .foregroundStyle(PluriColor.textPrimary)
                        Text("The full workout page — every exercise, sets and reps, and starting your session — arrives in the next update.")
                            .font(PluriFont.body)
                            .foregroundStyle(PluriColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, PluriSpacing.lg)
            .padding(.vertical, PluriSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .background(PluriColor.bgCanvas)
        .navigationTitle(session?.title ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func durationText(for session: PlannedSession) -> String {
        Duration.seconds(session.durationMinutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailStubView(session: nil)
    }
}
