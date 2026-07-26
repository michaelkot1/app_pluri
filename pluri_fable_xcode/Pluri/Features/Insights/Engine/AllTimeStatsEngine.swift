import Foundation

/// Pure all-time strength totals for Insights Performance (M5-09 / SPEC §9.1 / §14 #61).
///
/// Independent of the week filter. Aggregates **all** completed sessions from
/// `fetchAllCompletedSessions()` — plan-linked **and** manual `isManualLog`
/// rows (M5-12 / SPEC §9.3 / §14 #57e). Manual logs do **not** affect Pluri
/// Score plan-consistency. Runner distance / activity counts are v2 — not
/// computed here. Volume matches `PerformanceStatsEngine`:
/// `Σ(reps × weightKg)` when both are present.
nonisolated enum AllTimeStatsEngine {
    // MARK: - Inputs

    struct SetLogInput: Sendable, Equatable {
        var reps: Int?
        var weightKg: Double?
    }

    struct SessionInput: Sendable, Equatable {
        var id: UUID
        var durationSeconds: Int?
        var setLogs: [SetLogInput]
    }

    // MARK: - Output

    struct Stats: Sendable, Equatable {
        var workoutCount: Int
        var totalSets: Int
        var totalReps: Int
        /// Sum of `reps × weightKg` for weighted sets; `nil` if none.
        var totalVolumeKg: Double?
        /// Sum of session `durationSeconds` (missing durations count as 0).
        var totalDurationSeconds: Int

        static let empty = Stats(
            workoutCount: 0,
            totalSets: 0,
            totalReps: 0,
            totalVolumeKg: nil,
            totalDurationSeconds: 0
        )

        var isEmpty: Bool { workoutCount == 0 }
    }

    // MARK: - Aggregation

    static func aggregate(sessions: [SessionInput]) -> Stats {
        guard !sessions.isEmpty else { return .empty }

        var totalSets = 0
        var totalReps = 0
        var volumeKg: Double?
        var totalDurationSeconds = 0

        for session in sessions {
            totalDurationSeconds += max(0, session.durationSeconds ?? 0)
            for log in session.setLogs {
                totalSets += 1
                let reps = max(0, log.reps ?? 0)
                totalReps += reps
                if let weightKg = log.weightKg, let loggedReps = log.reps, loggedReps > 0 {
                    volumeKg = (volumeKg ?? 0) + (Double(loggedReps) * weightKg)
                }
            }
        }

        return Stats(
            workoutCount: sessions.count,
            totalSets: totalSets,
            totalReps: totalReps,
            totalVolumeKg: volumeKg,
            totalDurationSeconds: totalDurationSeconds
        )
    }
}
