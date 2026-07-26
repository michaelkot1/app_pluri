import Foundation
import SwiftData

/// One logged set within a `WorkoutSessionRecord` (M4-02).
///
/// Aligns with Postgres `set_logs`. Canonical weight storage is always
/// `weightKg` (SPEC §14 #50d) — UI converts to/from profile units later.
@Model
final class SetLogRecord {
    #Unique<SetLogRecord>([\.id])

    var id: UUID = UUID()
    var workoutExerciseId: UUID?
    var exerciseName: String = ""
    var setNumber: Int = 1
    var reps: Int?
    /// Canonical kilograms; never store display-unit pounds here.
    var weightKg: Double?
    var durationSeconds: Int?
    var createdAt: Date = Date()
    /// Cleared after a successful SyncEngine flush (M4-03).
    var needsSync: Bool = true

    var session: WorkoutSessionRecord?

    init(
        id: UUID = UUID(),
        workoutExerciseId: UUID?,
        exerciseName: String,
        setNumber: Int,
        reps: Int? = nil,
        weightKg: Double? = nil,
        durationSeconds: Int? = nil,
        createdAt: Date = .now,
        needsSync: Bool = true
    ) {
        self.id = id
        self.workoutExerciseId = workoutExerciseId
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
        self.needsSync = needsSync
    }
}
