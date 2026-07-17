import Foundation

/// One choice in the floating Record Workout menu (M3-09 / SPEC §5):
/// today's scheduled workout (when one exists) or Outdoor Run (always).
nonisolated enum HomeRecordOption: Equatable, Sendable, Identifiable {
    case scheduledWorkout(PlannedSession)
    case outdoorRun

    var id: String {
        switch self {
        case .scheduledWorkout(let session): "scheduled-\(session.id.uuidString)"
        case .outdoorRun: "outdoor-run"
        }
    }
}
