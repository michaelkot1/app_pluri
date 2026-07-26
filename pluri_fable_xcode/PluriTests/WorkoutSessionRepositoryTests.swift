import Foundation
import SwiftData
import Testing
@testable import Pluri

/// M4-02 — local-first `WorkoutSession` / `SetLog` persistence: create, log,
/// resume across contexts, complete, discard, uniqueness, notes, weight_kg.
@Suite("WorkoutSessionRepository")
@MainActor
struct WorkoutSessionRepositoryTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            CachedExercise.self,
            ExerciseCatalogSyncState.self,
            WorkoutSessionRecord.self,
            SetLogRecord.self,
        ])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeRepository(
        in container: ModelContainer
    ) -> SwiftDataWorkoutSessionRepository {
        SwiftDataWorkoutSessionRepository(modelContext: container.mainContext)
    }

    @Test("startOrResume creates an in-progress session")
    func startCreatesInProgress() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let userId = UUID()

        let session = try repo.startOrResume(planWorkoutId: planWorkoutId, userId: userId)

        #expect(session.planWorkoutId == planWorkoutId)
        #expect(session.userId == userId)
        #expect(session.endedAt == nil)
        #expect(session.isInProgress)
        #expect(session.activityType == "workout")
        #expect(session.needsSync)
        #expect(try repo.inProgressSession(for: planWorkoutId)?.id == session.id)
    }

    @Test("Mutations set needsSync on session and set logs (M4-03)")
    func mutationsSetNeedsSync() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let session = try repo.startOrResume(planWorkoutId: UUID(), userId: UUID())
        session.needsSync = false

        let set = try repo.upsertSetLog(
            sessionId: session.id,
            id: nil,
            workoutExerciseId: UUID(),
            exerciseName: "Row",
            setNumber: 1,
            reps: 10,
            weightKg: 40,
            durationSeconds: nil
        )
        #expect(session.needsSync)
        #expect(set.needsSync)

        session.needsSync = false
        set.needsSync = false
        try repo.updateWorkoutNotes(sessionId: session.id, notes: "Note")
        #expect(session.needsSync)

        session.needsSync = false
        try repo.complete(
            sessionId: session.id,
            endedAt: .now,
            durationSeconds: 60,
            notes: nil
        )
        #expect(session.needsSync)
    }

    @Test("startOrResume returns the same in-progress session (one per plan workout)")
    func startResumesExisting() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let userId = UUID()

        let first = try repo.startOrResume(planWorkoutId: planWorkoutId, userId: userId)
        let second = try repo.startOrResume(planWorkoutId: planWorkoutId, userId: userId)

        #expect(first.id == second.id)

        let all = try container.mainContext.fetch(FetchDescriptor<WorkoutSessionRecord>())
        #expect(all.count == 1)
    }

    @Test("upsertSetLog persists weightKg and resumes after a new context")
    func logSetsAndResumeAcrossContexts() throws {
        let container = try makeContainer()
        let planWorkoutId = UUID()
        let userId = UUID()
        let exerciseId = UUID()
        let sessionId: UUID

        do {
            let repo = makeRepository(in: container)
            let session = try repo.startOrResume(planWorkoutId: planWorkoutId, userId: userId)
            sessionId = session.id

            let set = try repo.upsertSetLog(
                sessionId: sessionId,
                id: nil,
                workoutExerciseId: exerciseId,
                exerciseName: "Bench Press",
                setNumber: 1,
                reps: 8,
                weightKg: 60.0,
                durationSeconds: nil
            )
            #expect(set.weightKg == 60.0)
            #expect(set.reps == 8)
            #expect(set.exerciseName == "Bench Press")
        }

        // Simulate relaunch: new repository on the same store.
        let repoAfterRelaunch = makeRepository(in: container)
        let resumed = try repoAfterRelaunch.startOrResume(
            planWorkoutId: planWorkoutId,
            userId: userId
        )
        #expect(resumed.id == sessionId)
        #expect(resumed.setLogs.count == 1)
        #expect(resumed.setLogs.first?.weightKg == 60.0)
        #expect(resumed.setLogs.first?.workoutExerciseId == exerciseId)
    }

    @Test("upsertSetLog updates an existing set by id")
    func upsertUpdatesExistingSet() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let session = try repo.startOrResume(planWorkoutId: UUID(), userId: UUID())
        let setId = UUID()

        _ = try repo.upsertSetLog(
            sessionId: session.id,
            id: setId,
            workoutExerciseId: UUID(),
            exerciseName: "Squat",
            setNumber: 1,
            reps: 5,
            weightKg: 100,
            durationSeconds: nil
        )
        _ = try repo.upsertSetLog(
            sessionId: session.id,
            id: setId,
            workoutExerciseId: UUID(),
            exerciseName: "Squat",
            setNumber: 1,
            reps: 6,
            weightKg: 102.5,
            durationSeconds: nil
        )

        #expect(session.setLogs.count == 1)
        #expect(session.setLogs.first?.reps == 6)
        #expect(session.setLogs.first?.weightKg == 102.5)
    }

    @Test("complete sets endedAt and duration; session is no longer in-progress")
    func completeSession() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let session = try repo.startOrResume(planWorkoutId: planWorkoutId, userId: UUID())
        let endedAt = Date(timeIntervalSince1970: 1_752_364_800)

        try repo.complete(
            sessionId: session.id,
            endedAt: endedAt,
            durationSeconds: 1_800,
            notes: "Felt strong"
        )

        #expect(session.endedAt == endedAt)
        #expect(session.durationSeconds == 1_800)
        #expect(session.notes == "Felt strong")
        #expect(!session.isInProgress)
        #expect(try repo.inProgressSession(for: planWorkoutId) == nil)

        // A new start is allowed for the same plan workout after complete.
        let next = try repo.startOrResume(planWorkoutId: planWorkoutId, userId: session.userId)
        #expect(next.id != session.id)
        #expect(next.isInProgress)
    }

    @Test("discard deletes session and set logs; allows a new start")
    func discardRemovesAndAllowsRestart() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let userId = UUID()
        let session = try repo.startOrResume(planWorkoutId: planWorkoutId, userId: userId)
        let sessionId = session.id

        _ = try repo.upsertSetLog(
            sessionId: sessionId,
            id: nil,
            workoutExerciseId: UUID(),
            exerciseName: "Row",
            setNumber: 1,
            reps: 10,
            weightKg: 40,
            durationSeconds: nil
        )

        try repo.discard(sessionId: sessionId)

        #expect(try repo.session(id: sessionId) == nil)
        #expect(try container.mainContext.fetch(FetchDescriptor<SetLogRecord>()).isEmpty)
        #expect(try repo.inProgressSession(for: planWorkoutId) == nil)

        let restarted = try repo.startOrResume(planWorkoutId: planWorkoutId, userId: userId)
        #expect(restarted.id != sessionId)
        #expect(restarted.isInProgress)
    }

    @Test("workout and per-exercise notes persist")
    func notesPersist() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let session = try repo.startOrResume(planWorkoutId: UUID(), userId: UUID())
        let exerciseId = UUID()

        try repo.updateWorkoutNotes(sessionId: session.id, notes: "Knee felt warm")
        try repo.updateExerciseNotes(
            sessionId: session.id,
            workoutExerciseId: exerciseId,
            notes: "Pause at bottom"
        )

        #expect(session.notes == "Knee felt warm")
        #expect(session.exerciseNotesByWorkoutExerciseId[exerciseId.uuidString] == "Pause at bottom")

        try repo.updateExerciseNotes(
            sessionId: session.id,
            workoutExerciseId: exerciseId,
            notes: nil
        )
        #expect(session.exerciseNotesByWorkoutExerciseId[exerciseId.uuidString] == nil)
    }

    @Test("weight is stored as kilograms")
    func weightStoredAsKilograms() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let session = try repo.startOrResume(planWorkoutId: UUID(), userId: UUID())

        // 225 lb ≈ 102.058 kg — callers convert before writing; we store kg.
        let kg = 102.058
        let set = try repo.upsertSetLog(
            sessionId: session.id,
            id: nil,
            workoutExerciseId: UUID(),
            exerciseName: "Deadlift",
            setNumber: 1,
            reps: 3,
            weightKg: kg,
            durationSeconds: nil
        )

        #expect(set.weightKg == kg)
    }

    @Test("fetchCompletedSessions returns ended sessions in the half-open window")
    func fetchCompletedSessionsInWindow() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let userId = UUID()
        let start = Date(timeIntervalSince1970: 1_752_451_200) // 2025-07-14
        let mid = start.addingTimeInterval(86_400)
        let end = start.addingTimeInterval(86_400 * 7)

        let inWindow = try repo.startOrResume(planWorkoutId: UUID(), userId: userId)
        _ = try repo.upsertSetLog(
            sessionId: inWindow.id,
            id: nil,
            workoutExerciseId: UUID(),
            exerciseName: "Bench",
            setNumber: 1,
            reps: 8,
            weightKg: 60,
            durationSeconds: nil
        )
        try repo.complete(
            sessionId: inWindow.id,
            endedAt: mid,
            durationSeconds: 600,
            notes: nil
        )

        let outside = try repo.startOrResume(planWorkoutId: UUID(), userId: userId)
        try repo.complete(
            sessionId: outside.id,
            endedAt: end.addingTimeInterval(3_600),
            durationSeconds: 600,
            notes: nil
        )

        let inProgress = try repo.startOrResume(planWorkoutId: UUID(), userId: userId)

        let fetched = try repo.fetchCompletedSessions(
            endingOnOrAfter: start,
            endingBefore: end
        )

        #expect(fetched.map(\.id) == [inWindow.id])
        #expect(fetched.first?.setLogs.count == 1)
        #expect(try repo.session(id: inProgress.id)?.endedAt == nil)
    }

    @Test("fetchAllCompletedSessions returns every ended session, oldest first")
    func fetchAllCompletedSessions() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let userId = UUID()
        let earlier = Date(timeIntervalSince1970: 1_752_451_200)
        let later = earlier.addingTimeInterval(86_400 * 3)

        let first = try repo.startOrResume(planWorkoutId: UUID(), userId: userId)
        try repo.complete(
            sessionId: first.id,
            endedAt: earlier,
            durationSeconds: 600,
            notes: nil
        )

        let second = try repo.startOrResume(planWorkoutId: UUID(), userId: userId)
        try repo.complete(
            sessionId: second.id,
            endedAt: later,
            durationSeconds: 900,
            notes: nil
        )

        _ = try repo.startOrResume(planWorkoutId: UUID(), userId: userId)

        let fetched = try repo.fetchAllCompletedSessions()
        #expect(fetched.map(\.id) == [first.id, second.id])
        #expect(fetched.map(\.durationSeconds) == [600, 900])
    }

    @Test("createManualActivity inserts completed isManualLog session included in fetchAll")
    func createManualActivity() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let userId = UUID()
        let startedAt = Date(timeIntervalSince1970: 1_784_073_600)

        let manual = try repo.createManualActivity(
            userId: userId,
            activityType: "cardio",
            startedAt: startedAt,
            durationSeconds: 1_800,
            distanceMeters: 5_000,
            notes: "Easy run"
        )

        #expect(manual.isManualLog)
        #expect(manual.planWorkoutId == nil)
        #expect(manual.needsSync)
        #expect(manual.activityType == "cardio")
        #expect(manual.durationSeconds == 1_800)
        #expect(manual.distanceMeters == 5_000)
        #expect(manual.notes == "Easy run")
        #expect(manual.endedAt == startedAt.addingTimeInterval(1_800))
        #expect(!manual.isInProgress)

        let plan = try repo.startOrResume(planWorkoutId: UUID(), userId: userId)
        try repo.complete(
            sessionId: plan.id,
            endedAt: startedAt.addingTimeInterval(3_600),
            durationSeconds: 600,
            notes: nil
        )

        let fetched = try repo.fetchAllCompletedSessions()
        #expect(fetched.map(\.id) == [manual.id, plan.id])
        #expect(fetched.contains { $0.isManualLog && $0.id == manual.id })
    }

    @Test("startOrResume creates a soft paused session without a running timer")
    func softStartDoesNotRunTimer() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let session = try repo.startOrResume(planWorkoutId: UUID(), userId: UUID())

        #expect(session.isPaused)
        #expect(session.lastResumedAt == nil)
        #expect(!session.hasStartedLiveTimer)
        #expect(session.accumulatedActiveSeconds == 0)
        #expect(session.displayedElapsedSeconds() == 0)
    }

    @Test("pause folds elapsed; resume begins a new running segment")
    func pauseAndResumeElapsed() async throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let session = try repo.startOrResume(planWorkoutId: UUID(), userId: UUID())

        try repo.resume(sessionId: session.id)
        #expect(!session.isPaused)
        #expect(session.hasStartedLiveTimer)
        #expect(session.lastResumedAt != nil)

        session.accumulatedActiveSeconds = 10
        session.lastResumedAt = Date.now.addingTimeInterval(-5)
        try repo.pause(sessionId: session.id)

        #expect(session.isPaused)
        #expect(session.lastResumedAt == nil)
        #expect(session.accumulatedActiveSeconds >= 15)
        #expect(session.durationSeconds == session.accumulatedActiveSeconds)

        try repo.resume(sessionId: session.id)
        #expect(!session.isPaused)
        #expect(session.lastResumedAt != nil)
        let afterResume = session.accumulatedActiveSeconds
        #expect(session.displayedElapsedSeconds() >= afterResume)
    }
}
