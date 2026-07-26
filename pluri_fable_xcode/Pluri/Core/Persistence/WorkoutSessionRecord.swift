import Foundation
import SwiftData

/// Local SwiftData record for a performed (or in-progress) workout session (M4-02).
///
/// Aligns with Postgres `workout_sessions` for future SyncEngine (M4-03), plus
/// local-only pause / elapsed fields and per-exercise notes that have no remote
/// columns yet (SPEC §14 #51).
///
/// Lifecycle: `endedAt == nil` means in-progress; a non-nil `endedAt` means
/// completed. Discard deletes the row entirely.
@Model
final class WorkoutSessionRecord {
    #Unique<WorkoutSessionRecord>([\.id])

    var id: UUID = UUID()
    var userId: UUID = UUID()
    /// Linked plan workout when started from a plan; nil for manual logs (v1 rare).
    var planWorkoutId: UUID?
    /// Mirrors Postgres CHECK: `workout` | `cardio` | `flexibility`.
    var activityType: String = "workout"
    var startedAt: Date = Date()
    var endedAt: Date?
    var durationSeconds: Int?
    var distanceMeters: Double?
    /// Workout-level notes (SPEC §7 / §8.1).
    var notes: String?
    var syncedToHealth: Bool = false
    var isManualLog: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Cleared after a successful SyncEngine flush (M4-03). Default true so
    /// new/mutated sessions upload opportunistically when online.
    var needsSync: Bool = true

    // MARK: Local-only (not in Postgres — SPEC §14 #51)

    /// Pause state for the live timer (M4-09).
    var isPaused: Bool = false
    /// Seconds of active (non-paused) time accumulated so far.
    var accumulatedActiveSeconds: Int = 0
    /// When the timer last entered a running (unpaused) segment; nil when paused
    /// or before first start segment is tracked by UI.
    var lastResumedAt: Date?
    /// Per-exercise notes keyed by `workoutExerciseId.uuidString` (local-only).
    var exerciseNotesByWorkoutExerciseId: [String: String] = [:]

    @Relationship(deleteRule: .cascade, inverse: \SetLogRecord.session)
    var setLogs: [SetLogRecord] = []

    /// In-progress when the session has not been completed.
    var isInProgress: Bool { endedAt == nil }

    init(
        id: UUID = UUID(),
        userId: UUID,
        planWorkoutId: UUID?,
        activityType: String = "workout",
        startedAt: Date = .now,
        endedAt: Date? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil,
        notes: String? = nil,
        syncedToHealth: Bool = false,
        isManualLog: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        needsSync: Bool = true,
        isPaused: Bool = false,
        accumulatedActiveSeconds: Int = 0,
        lastResumedAt: Date? = nil,
        exerciseNotesByWorkoutExerciseId: [String: String] = [:]
    ) {
        self.id = id
        self.userId = userId
        self.planWorkoutId = planWorkoutId
        self.activityType = activityType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.notes = notes
        self.syncedToHealth = syncedToHealth
        self.isManualLog = isManualLog
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.needsSync = needsSync
        self.isPaused = isPaused
        self.accumulatedActiveSeconds = accumulatedActiveSeconds
        self.lastResumedAt = lastResumedAt
        self.exerciseNotesByWorkoutExerciseId = exerciseNotesByWorkoutExerciseId
    }
}
