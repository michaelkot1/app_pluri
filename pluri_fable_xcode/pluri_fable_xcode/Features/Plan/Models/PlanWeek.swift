import Foundation

/// One week of a `GeneratedPlan` (M1-16): a numbered bucket of sessions.
///
/// The engine repeats the same session templates each week and applies
/// progression (SPEC §14), so later weeks carry the same movements with
/// higher rep/set targets.
nonisolated struct PlanWeek: Identifiable, Hashable, Sendable {
    let id: UUID

    /// 1-based week number.
    let number: Int

    let sessions: [PlannedSession]

    init(id: UUID = UUID(), number: Int, sessions: [PlannedSession]) {
        self.id = id
        self.number = number
        self.sessions = sessions
    }
}
