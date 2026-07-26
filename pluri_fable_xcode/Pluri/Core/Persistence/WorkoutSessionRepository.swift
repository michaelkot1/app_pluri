import Foundation
import Observation
import SwiftData
import os.log

/// Local-first persistence for in-progress and completed workout sessions (M4-02).
///
/// Every mutating call saves immediately so a kill/crash cannot lose progress
/// (SPEC §13 / §14 #50c). Does **not** mutate `PlanStore` — Start/complete/
/// discard are session-local only until M4-03/04/14.
@MainActor
protocol WorkoutSessionRepository: AnyObject {
    /// Returns the existing in-progress session for `planWorkoutId`, or creates one.
    /// Enforces at most one in-progress session per `planWorkoutId` (SPEC §14 #50c).
    func startOrResume(planWorkoutId: UUID, userId: UUID) throws -> WorkoutSessionRecord

    /// The in-progress session for a plan workout, if any.
    func inProgressSession(for planWorkoutId: UUID) throws -> WorkoutSessionRecord?

    func session(id: UUID) throws -> WorkoutSessionRecord?

    /// Inserts or updates a set log and saves immediately.
    @discardableResult
    func upsertSetLog(
        sessionId: UUID,
        id: UUID?,
        workoutExerciseId: UUID?,
        exerciseName: String,
        setNumber: Int,
        reps: Int?,
        weightKg: Double?,
        durationSeconds: Int?
    ) throws -> SetLogRecord

    func updateWorkoutNotes(sessionId: UUID, notes: String?) throws

    /// Per-exercise notes (local-only map keyed by workout exercise id).
    func updateExerciseNotes(sessionId: UUID, workoutExerciseId: UUID, notes: String?) throws

    /// Folds the current running segment into `accumulatedActiveSeconds` and pauses.
    func pause(sessionId: UUID) throws

    /// Begins (or resumes) a running timer segment. First call after a soft
    /// Detail-notes session is the live Screen Start (SPEC §14 #55).
    func resume(sessionId: UUID) throws

    /// Marks the session completed. Does not change plan workout status.
    func complete(
        sessionId: UUID,
        endedAt: Date,
        durationSeconds: Int?,
        notes: String?
    ) throws

    /// Deletes the session and its set logs. Plan workout status is unchanged.
    func discard(sessionId: UUID) throws
}

enum WorkoutSessionRepositoryError: Error, Equatable {
    case sessionNotFound
    case sessionAlreadyCompleted
}

/// SwiftData-backed `WorkoutSessionRepository`.
///
/// `@Observable` so AppRoot can inject it via `.environment` (M4-05/06 Notes).
@MainActor
@Observable
final class SwiftDataWorkoutSessionRepository: WorkoutSessionRepository {
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.codewithmikey.pluri", category: "WorkoutSessionRepository")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func startOrResume(planWorkoutId: UUID, userId: UUID) throws -> WorkoutSessionRecord {
        if let existing = try inProgressSession(for: planWorkoutId) {
            return existing
        }

        // Soft in-progress only — timer stays idle until Screen Start calls resume
        // (Detail Notes / soft Start must not auto-run; SPEC §14 #55).
        let session = WorkoutSessionRecord(
            userId: userId,
            planWorkoutId: planWorkoutId,
            activityType: "workout",
            startedAt: .now,
            isPaused: true,
            accumulatedActiveSeconds: 0,
            lastResumedAt: nil,
            hasStartedLiveTimer: false
        )
        modelContext.insert(session)
        try save()
        logger.info("Started workout session \(session.id.uuidString, privacy: .public)")
        return session
    }

    func inProgressSession(for planWorkoutId: UUID) throws -> WorkoutSessionRecord? {
        var descriptor = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { session in
                session.planWorkoutId == planWorkoutId && session.endedAt == nil
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func session(id: UUID) throws -> WorkoutSessionRecord? {
        var descriptor = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { session in
                session.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    func upsertSetLog(
        sessionId: UUID,
        id: UUID?,
        workoutExerciseId: UUID?,
        exerciseName: String,
        setNumber: Int,
        reps: Int?,
        weightKg: Double?,
        durationSeconds: Int?
    ) throws -> SetLogRecord {
        guard let session = try session(id: sessionId) else {
            throw WorkoutSessionRepositoryError.sessionNotFound
        }

        let record: SetLogRecord
        if let id, let existing = session.setLogs.first(where: { $0.id == id }) {
            existing.workoutExerciseId = workoutExerciseId
            existing.exerciseName = exerciseName
            existing.setNumber = setNumber
            existing.reps = reps
            existing.weightKg = weightKg
            existing.durationSeconds = durationSeconds
            existing.needsSync = true
            record = existing
        } else {
            let created = SetLogRecord(
                id: id ?? UUID(),
                workoutExerciseId: workoutExerciseId,
                exerciseName: exerciseName,
                setNumber: setNumber,
                reps: reps,
                weightKg: weightKg,
                durationSeconds: durationSeconds,
                needsSync: true
            )
            created.session = session
            session.setLogs.append(created)
            modelContext.insert(created)
            record = created
        }

        session.updatedAt = .now
        session.needsSync = true
        try save()
        return record
    }

    func updateWorkoutNotes(sessionId: UUID, notes: String?) throws {
        guard let session = try session(id: sessionId) else {
            throw WorkoutSessionRepositoryError.sessionNotFound
        }
        session.notes = notes
        session.updatedAt = .now
        session.needsSync = true
        try save()
    }

    func updateExerciseNotes(sessionId: UUID, workoutExerciseId: UUID, notes: String?) throws {
        guard let session = try session(id: sessionId) else {
            throw WorkoutSessionRepositoryError.sessionNotFound
        }
        let key = workoutExerciseId.uuidString
        var map = session.exerciseNotesByWorkoutExerciseId
        if let notes, !notes.isEmpty {
            map[key] = notes
        } else {
            map.removeValue(forKey: key)
        }
        session.exerciseNotesByWorkoutExerciseId = map
        session.updatedAt = .now
        // Local-only field (#51) — bump session bookkeeping so a later flush
        // still carries the parent row's updated_at, without requiring a set_log.
        session.needsSync = true
        try save()
    }

    func pause(sessionId: UUID) throws {
        guard let session = try session(id: sessionId) else {
            throw WorkoutSessionRepositoryError.sessionNotFound
        }
        guard session.isInProgress else {
            throw WorkoutSessionRepositoryError.sessionAlreadyCompleted
        }
        if !session.isPaused, let lastResumedAt = session.lastResumedAt {
            let delta = max(0, Int(Date.now.timeIntervalSince(lastResumedAt)))
            session.accumulatedActiveSeconds += delta
        }
        session.isPaused = true
        session.lastResumedAt = nil
        session.durationSeconds = session.accumulatedActiveSeconds
        session.updatedAt = .now
        session.needsSync = true
        try save()
    }

    func resume(sessionId: UUID) throws {
        guard let session = try session(id: sessionId) else {
            throw WorkoutSessionRepositoryError.sessionNotFound
        }
        guard session.isInProgress else {
            throw WorkoutSessionRepositoryError.sessionAlreadyCompleted
        }
        guard session.isPaused || session.lastResumedAt == nil else {
            // Already running — idempotent.
            return
        }
        session.isPaused = false
        session.lastResumedAt = .now
        session.hasStartedLiveTimer = true
        session.updatedAt = .now
        session.needsSync = true
        try save()
    }

    func complete(
        sessionId: UUID,
        endedAt: Date,
        durationSeconds: Int?,
        notes: String?
    ) throws {
        guard let session = try session(id: sessionId) else {
            throw WorkoutSessionRepositoryError.sessionNotFound
        }
        guard session.isInProgress else {
            throw WorkoutSessionRepositoryError.sessionAlreadyCompleted
        }
        session.endedAt = endedAt
        session.durationSeconds = durationSeconds
        if let notes {
            session.notes = notes
        }
        session.isPaused = true
        session.lastResumedAt = nil
        session.updatedAt = .now
        session.needsSync = true
        try save()
        logger.info("Completed workout session \(sessionId.uuidString, privacy: .public)")
    }

    func discard(sessionId: UUID) throws {
        guard let session = try session(id: sessionId) else {
            throw WorkoutSessionRepositoryError.sessionNotFound
        }
        modelContext.delete(session)
        try save()
        logger.info("Discarded workout session \(sessionId.uuidString, privacy: .public)")
    }

    private func save() throws {
        try modelContext.save()
    }
}
