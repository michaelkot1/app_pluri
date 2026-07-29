import Foundation

/// One real planned workout available from Home's Record Workout menu.
nonisolated enum HomeRecordOption: Equatable, Sendable, Identifiable {
    case scheduledWorkout(PlannedSession)

    var id: String {
        switch self {
        case .scheduledWorkout(let session): "scheduled-\(session.id.uuidString)"
        }
    }
}
