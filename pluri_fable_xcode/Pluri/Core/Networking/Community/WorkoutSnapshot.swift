import Foundation

/// Share Workout payload stored on `posts.workout_snapshot` jsonb
/// (SPEC §14 #72e). Compact summary only — never HealthKit samples or
/// raw set-log dumps.
struct WorkoutSnapshot: Codable, Sendable, Equatable, Hashable {
    var sessionId: UUID?
    /// Plan title resolved via `planWorkoutId` when present, else a gentle label.
    var title: String?
    var activityType: String
    var durationSeconds: Int?
    var distanceMeters: Double?
    var setCount: Int?
    var repCount: Int?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case title
        case activityType = "activity_type"
        case durationSeconds = "duration_seconds"
        case distanceMeters = "distance_meters"
        case setCount = "set_count"
        case repCount = "rep_count"
    }

    /// Builds a compact snapshot from a completed local session (M8-07).
    static func from(
        session: WorkoutSessionRecord,
        title: String?
    ) -> WorkoutSnapshot {
        let sets = session.setLogs
        let repTotal = sets.reduce(0) { partial, log in
            partial + (log.reps ?? 0)
        }
        let resolvedTitle: String?
        if let title {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            resolvedTitle = trimmed.isEmpty ? nil : trimmed
        } else {
            resolvedTitle = nil
        }
        return WorkoutSnapshot(
            sessionId: session.id,
            title: resolvedTitle ?? Self.fallbackTitle(for: session.activityType),
            activityType: session.activityType,
            durationSeconds: session.durationSeconds,
            distanceMeters: session.distanceMeters,
            setCount: sets.isEmpty ? nil : sets.count,
            repCount: sets.isEmpty ? nil : repTotal
        )
    }

    private static func fallbackTitle(for activityType: String) -> String {
        switch activityType {
        case "cardio": "Cardio session"
        case "flexibility": "Flexibility session"
        default: "Workout"
        }
    }
}
