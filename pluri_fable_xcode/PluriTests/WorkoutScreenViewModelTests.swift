import Foundation
import SwiftData
import Testing
@testable import Pluri

/// M4-07–11 — Start / timer / pause / log / HealthKit display.
@Suite("WorkoutScreenViewModel")
@MainActor
struct WorkoutScreenViewModelTests {

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

    private func makeExercise(id: UUID = UUID()) -> PlannedExercise {
        PlannedExercise(
            id: id,
            exerciseID: "bench",
            name: "Bench",
            bodyPart: "Chest",
            equipment: "Barbell",
            targetMuscle: "Pectorals",
            secondaryMuscles: [],
            imageURL: nil,
            order: 0,
            sets: 3,
            reps: 10
        )
    }

    @Test("Start creates an in-progress session and begins the live timer")
    func startCreatesSessionAndRunsTimer() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let userId = UUID()
        let viewModel = WorkoutScreenViewModel(
            sessionID: planWorkoutId,
            repository: repo,
            userIDProvider: { userId }
        )

        viewModel.start()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isSessionInProgress)
        #expect(viewModel.hasStartedLiveTimer)
        #expect(viewModel.isRunning)
        #expect(!viewModel.isPaused)
        let session = try #require(try repo.inProgressSession(for: planWorkoutId))
        #expect(session.id == viewModel.workoutSessionID)
        #expect(session.hasStartedLiveTimer)
        #expect(!session.isPaused)
        #expect(session.lastResumedAt != nil)
    }

    @Test("Start resumes an existing soft session and begins the timer")
    func startResumesExistingAndBeginsTimer() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let userId = UUID()
        let existing = try repo.startOrResume(planWorkoutId: planWorkoutId, userId: userId)
        #expect(existing.isPaused)
        #expect(!existing.hasStartedLiveTimer)

        let viewModel = WorkoutScreenViewModel(
            sessionID: planWorkoutId,
            repository: repo,
            userIDProvider: { userId }
        )
        viewModel.start()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.workoutSessionID == existing.id)
        #expect(viewModel.isRunning)
        #expect(try repo.session(id: existing.id)?.hasStartedLiveTimer == true)
    }

    @Test("Detail-notes soft session does not auto-run the timer until Screen Start")
    func softNotesDoNotRunTimer() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let exerciseID = UUID()
        let userId = UUID()
        let viewModel = WorkoutScreenViewModel(
            sessionID: planWorkoutId,
            repository: repo,
            userIDProvider: { userId }
        )

        viewModel.updateExerciseNotesDraft("Elbows tucked", for: exerciseID)
        viewModel.saveExerciseNotes(for: exerciseID)
        viewModel.refreshSessionState()

        #expect(viewModel.isSessionInProgress)
        #expect(!viewModel.hasStartedLiveTimer)
        #expect(!viewModel.isRunning)
        #expect(viewModel.displayedElapsedSeconds == 0)
        #expect(viewModel.showsLiveControls == false)
    }

    @Test("pause and resume update repository elapsed state")
    func pauseAndResume() async throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let userId = UUID()
        let viewModel = WorkoutScreenViewModel(
            sessionID: planWorkoutId,
            repository: repo,
            userIDProvider: { userId }
        )
        viewModel.start()
        let sessionId = try #require(viewModel.workoutSessionID)

        try await Task.sleep(for: .milliseconds(50))
        viewModel.pause()

        #expect(viewModel.isPaused)
        #expect(!viewModel.isRunning)
        let paused = try #require(try repo.session(id: sessionId))
        #expect(paused.isPaused)
        #expect(paused.lastResumedAt == nil)

        viewModel.resume()
        #expect(viewModel.isRunning)
        #expect(!viewModel.isPaused)
        let resumed = try #require(try repo.session(id: sessionId))
        #expect(!resumed.isPaused)
        #expect(resumed.lastResumedAt != nil)
    }

    @Test("stop pauses without preparing completion handoff")
    func stopPausesWithoutHandoff() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let userId = UUID()
        let viewModel = WorkoutScreenViewModel(
            sessionID: planWorkoutId,
            repository: repo,
            userIDProvider: { userId }
        )
        viewModel.start()
        let sessionId = try #require(viewModel.workoutSessionID)
        viewModel.stop()

        #expect(viewModel.pendingCompletion == nil)
        #expect(viewModel.isPaused)
        #expect(!viewModel.isRunning)
        let session = try #require(try repo.session(id: sessionId))
        #expect(session.isPaused)
        #expect(session.endedAt == nil)
        #expect(session.isInProgress)
    }

    @Test("finish prepares completion handoff (hold-to-finish)")
    func finishPreparesHandoff() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let userId = UUID()
        let viewModel = WorkoutScreenViewModel(
            sessionID: planWorkoutId,
            repository: repo,
            userIDProvider: { userId }
        )
        viewModel.start()
        let sessionId = try #require(viewModel.workoutSessionID)
        viewModel.finish()

        #expect(viewModel.pendingCompletion?.planWorkoutID == planWorkoutId)
        #expect(viewModel.pendingCompletion?.workoutSessionID == sessionId)
        #expect(viewModel.pendingCompletion?.elapsedSeconds != nil)
        let session = try #require(try repo.session(id: sessionId))
        #expect(session.isPaused)
        #expect(session.endedAt == nil)
        #expect(session.isInProgress)
    }

    @Test("WorkoutWeightInput filters and parses locale decimals; empty is bodyweight")
    func weightInputFilteringAndParsing() {
        #expect(WorkoutWeightInput.filtered("12a.3b4") == "12.34")
        #expect(WorkoutWeightInput.filtered("12,5") == "12,5")
        #expect(WorkoutWeightInput.filtered("1.2.3") == "1.23")
        #expect(WorkoutWeightInput.parse("") == .empty)
        #expect(WorkoutWeightInput.parse("  ") == .empty)
        #expect(WorkoutWeightInput.parse("60") == .valid(60))
        #expect(WorkoutWeightInput.parse("12,5") == .valid(12.5))
        #expect(WorkoutWeightInput.parse(".") == .invalid)
        #expect(WorkoutWeightInput.canLog(""))
        #expect(WorkoutWeightInput.canLog("45.5"))
        #expect(!WorkoutWeightInput.canLog("."))
    }

    @Test("logSet rejects non-finite or negative weight display")
    func logSetRejectsInvalidWeight() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let userId = UUID()
        let exercise = makeExercise()
        let viewModel = WorkoutScreenViewModel(
            sessionID: planWorkoutId,
            repository: repo,
            userIDProvider: { userId }
        )
        viewModel.start()

        viewModel.logSet(exercise: exercise, reps: 8, weightDisplay: -5)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.loggedSetCountByExercise[exercise.id] == nil)

        viewModel.logSet(exercise: exercise, reps: 8, weightDisplay: .nan)
        #expect(viewModel.errorMessage != nil)

        viewModel.logSet(exercise: exercise, reps: 8, weightDisplay: nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.loggedSetCountByExercise[exercise.id] == 1)
    }

    @Test("refreshSessionState restores pause and elapsed after relaunch")
    func refreshRestoresPauseAndElapsed() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let userId = UUID()
        let session = try repo.startOrResume(planWorkoutId: planWorkoutId, userId: userId)
        try repo.resume(sessionId: session.id)
        session.accumulatedActiveSeconds = 125
        try repo.pause(sessionId: session.id)

        let viewModel = WorkoutScreenViewModel(
            sessionID: planWorkoutId,
            repository: repo,
            userIDProvider: { userId }
        )
        viewModel.refreshSessionState()

        #expect(viewModel.hasStartedLiveTimer)
        #expect(viewModel.isPaused)
        #expect(!viewModel.isRunning)
        #expect(viewModel.displayedElapsedSeconds == 125)
    }

    @Test("logSet stores weightKg for imperial display and increments set numbers")
    func logSetImperialAndIncrements() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let userId = UUID()
        let sync = MockSyncEngine()
        sync.flushOnEnqueue = false
        let exercise = makeExercise()
        let viewModel = WorkoutScreenViewModel(
            sessionID: planWorkoutId,
            repository: repo,
            userIDProvider: { userId },
            syncEngine: sync,
            usesImperialUnits: { true }
        )
        viewModel.start()

        viewModel.logSet(exercise: exercise, reps: 8, weightDisplay: 225)
        viewModel.logSet(exercise: exercise, reps: 6, weightDisplay: 230)

        let session = try #require(try repo.inProgressSession(for: planWorkoutId))
        let logs = session.setLogs.sorted { $0.setNumber < $1.setNumber }
        #expect(logs.count == 2)
        #expect(logs[0].setNumber == 1)
        #expect(logs[1].setNumber == 2)
        let expectedKg = Measurement(value: 225, unit: UnitMass.pounds)
            .converted(to: .kilograms)
            .value
        #expect(logs[0].weightKg == expectedKg)
        #expect(viewModel.loggedSetCountByExercise[exercise.id] == 2)
        #expect(viewModel.loggedSets(for: exercise.id).count == 2)
        #expect(viewModel.loggedSets(for: exercise.id)[0].reps == 8)
        let lastDisplay = try #require(viewModel.lastLoggedWeightDisplay(for: exercise.id))
        #expect(abs(lastDisplay - 230) < 0.05)
        #expect(sync.enqueueCalls.count == 2)
    }

    @Test("logSet duration writes durationSeconds")
    func logSetDuration() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let userId = UUID()
        let exercise = makeExercise()
        let viewModel = WorkoutScreenViewModel(
            sessionID: planWorkoutId,
            repository: repo,
            userIDProvider: { userId }
        )
        viewModel.start()
        viewModel.logSet(exercise: exercise, reps: 0, weightDisplay: nil, durationSeconds: 45)

        let session = try #require(try repo.inProgressSession(for: planWorkoutId))
        #expect(session.setLogs.first?.durationSeconds == 45)
        #expect(session.setLogs.first?.reps == nil)
    }

    @Test("Authorized health metrics show values; unauthorized stays em-dash; pause stops streaming")
    func healthMetricsLifecycle() async throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let unauthorized = MockWorkoutHealthMetricsProvider(isAuthorized: false)
        let planWorkoutId = UUID()
        let userId = UUID()
        let viewModel = WorkoutScreenViewModel(
            sessionID: planWorkoutId,
            repository: repo,
            userIDProvider: { userId },
            healthMetrics: unauthorized
        )

        #expect(viewModel.heartRateDisplay == "—")
        #expect(viewModel.caloriesDisplay == "—")

        viewModel.start()
        try await Task.sleep(for: .milliseconds(20))
        #expect(unauthorized.authorizationRequestCount == 1)
        #expect(unauthorized.isStreaming)
        #expect(viewModel.heartRateDisplay == "128")
        #expect(viewModel.caloriesDisplay == "42")

        viewModel.pause()
        #expect(!unauthorized.isStreaming)
        #expect(viewModel.heartRateDisplay == "—")
        #expect(unauthorized.stopStreamingCount >= 1)
    }

    @Test("Saving exercise notes creates/resumes then persists notes")
    func saveExerciseNotes() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let exerciseID = UUID()
        let userId = UUID()
        let viewModel = WorkoutScreenViewModel(
            sessionID: planWorkoutId,
            repository: repo,
            userIDProvider: { userId }
        )

        viewModel.updateExerciseNotesDraft("  Elbows tucked  ", for: exerciseID)
        viewModel.saveExerciseNotes(for: exerciseID)

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.notesDraft(for: exerciseID) == "Elbows tucked")
        #expect(viewModel.isSessionInProgress)
        #expect(!viewModel.hasStartedLiveTimer)
        let session = try #require(try repo.inProgressSession(for: planWorkoutId))
        #expect(session.exerciseNotesByWorkoutExerciseId[exerciseID.uuidString] == "Elbows tucked")
    }

    @Test("Start without a user surfaces a gentle missing-user message")
    func startRequiresUser() {
        let container = try! makeContainer()
        let repo = makeRepository(in: container)
        let viewModel = WorkoutScreenViewModel(
            sessionID: UUID(),
            repository: repo,
            userIDProvider: { nil }
        )

        viewModel.start()

        #expect(viewModel.errorMessage == PlanMutationError.missingUser.userFacingMessage)
        #expect(!viewModel.isSessionInProgress)
    }

    @Test("Description joins catalog instructions; empty when missing")
    func descriptionFromCatalog() {
        let container = try! makeContainer()
        let repo = makeRepository(in: container)
        let exercise = makeExercise()
        let catalog = Exercise(
            id: "bench",
            name: "Bench",
            bodyPart: "Chest",
            equipment: "Barbell",
            targetMuscle: "Pectorals",
            secondaryMuscles: [],
            instructions: ["Lie flat.", "Press up."],
            imageURL: nil,
            videoURL: nil
        )
        let withCatalog = WorkoutScreenViewModel(
            sessionID: UUID(),
            repository: repo,
            userIDProvider: { UUID() },
            catalogLookup: { id in id == "bench" ? catalog : nil }
        )
        #expect(withCatalog.description(for: exercise) == "Lie flat.\n\nPress up.")

        let missing = WorkoutScreenViewModel(
            sessionID: UUID(),
            repository: repo,
            userIDProvider: { UUID() },
            catalogLookup: { _ in nil }
        )
        #expect(missing.description(for: exercise).isEmpty)
    }

    @Test("Separate plan workout IDs keep independent timer / running state")
    func sessionIsolationAcrossPlanWorkouts() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let userId = UUID()
        let workoutA = UUID()
        let workoutB = UUID()

        let viewModelA = WorkoutScreenViewModel(
            sessionID: workoutA,
            repository: repo,
            userIDProvider: { userId }
        )
        viewModelA.start()
        viewModelA.pause()
        #expect(viewModelA.hasStartedLiveTimer)
        #expect(viewModelA.isPaused)
        #expect(viewModelA.workoutSessionID != nil)

        let viewModelB = WorkoutScreenViewModel(
            sessionID: workoutB,
            repository: repo,
            userIDProvider: { userId }
        )
        viewModelB.refreshSessionState()

        #expect(viewModelB.displayedElapsedSeconds == 0)
        #expect(!viewModelB.hasStartedLiveTimer)
        #expect(!viewModelB.isRunning)
        #expect(!viewModelB.isPaused)
        #expect(viewModelB.workoutSessionID == nil)
        // A remains unchanged after B is constructed/refreshed.
        #expect(viewModelA.hasStartedLiveTimer)
        #expect(viewModelA.isPaused)
    }

    @Test("resolvedVideoURL prefers planned URL then catalog fallback")
    func resolvedVideoURLFallback() {
        let container = try! makeContainer()
        let repo = makeRepository(in: container)
        let plannedURL = URL(string: "https://cdn.example/exercises/planned.mp4")!
        let catalogURL = URL(string: "https://cdn.example/exercises/catalog.mp4")!
        let catalog = Exercise(
            id: "bench",
            name: "Bench",
            bodyPart: "Chest",
            equipment: "Barbell",
            targetMuscle: "Pectorals",
            secondaryMuscles: [],
            instructions: [],
            imageURL: nil,
            videoURL: catalogURL
        )
        let viewModel = WorkoutScreenViewModel(
            sessionID: UUID(),
            repository: repo,
            userIDProvider: { UUID() },
            catalogLookup: { id in id == "bench" ? catalog : nil }
        )

        let withPlanned = PlannedExercise(
            exerciseID: "bench",
            name: "Bench",
            bodyPart: "Chest",
            equipment: "Barbell",
            targetMuscle: "Pectorals",
            secondaryMuscles: [],
            imageURL: nil,
            videoURL: plannedURL,
            order: 0,
            sets: 3,
            reps: 10
        )
        #expect(viewModel.resolvedVideoURL(for: withPlanned) == plannedURL)

        // A plan generated before the mirror covered this exercise carries no
        // video of its own and must pick the catalog's up (SPEC §14 #79).
        let withoutPlanned = makeExercise()
        #expect(viewModel.resolvedVideoURL(for: withoutPlanned) == catalogURL)
    }
}
