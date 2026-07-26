import SwiftUI

/// Resolves a pushed `InsightsRoute` to its destination view (M5-17).
/// Plan-linked Detail / Screen / Completion reuse M4 workout surfaces with
/// Insights stack affinity; manual logs use completed-session detail.
struct InsightsRouteDestinationView: View {
    var route: InsightsRoute

    var body: some View {
        switch route {
        case .workoutDetail(let planWorkoutID):
            WorkoutDetailView(sessionID: planWorkoutID, stack: .insights)
        case .completedSession(let sessionID):
            InsightsCompletedSessionDetailView(sessionID: sessionID)
        case .workoutScreen(let planWorkoutID):
            WorkoutScreenView(sessionID: planWorkoutID, stack: .insights)
        case .workoutCompletion(let planWorkoutID, let workoutSessionID, let elapsedSeconds):
            WorkoutCompletionView(
                planWorkoutID: planWorkoutID,
                workoutSessionID: workoutSessionID,
                elapsedSeconds: elapsedSeconds,
                stack: .insights
            )
        }
    }
}
