import Foundation

/// Maps a plan-mutation failure to gentle user-facing copy (M3-13/14):
/// typed validation and sync errors keep their own kind messages; anything
/// unexpected falls back to a soft generic line — this app never scolds.
nonisolated enum PlanChangeErrorMessage {
    static func message(for error: any Error) -> String {
        if let mutation = error as? PlanMutationError {
            return mutation.userFacingMessage
        }
        if let sync = error as? PluriSyncError {
            return sync.userFacingMessage
        }
        if let engine = error as? PlanEngineError {
            return engine.userFacingMessage
        }
        return "We couldn't save that change just now. Please try again."
    }
}
