import Foundation
import SwiftData
import Testing
@testable import Pluri

/// M4-12/13/14 — Discard / Save orchestration, totals, Health toggle, SyncEngine enqueue.
@Suite("WorkoutCompletionViewModel")
@MainActor
struct WorkoutCompletionViewModelTests {

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

    private func makeScheduledPlan(title: String = "Push") -> GeneratedPlan {
        let calendar = Calendar.current
        var monday = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_752_364_800))
        while calendar.component(.weekday, from: monday) != Weekday.monday.rawValue {
            monday = calendar.date(byAdding: .day, value: 1, to: monday) ?? monday
        }
        let date = calendar.date(byAdding: .day, value: 7, to: monday) ?? monday
        let session = PlannedSession(
            title: title,
            indexInWeek: 1,
            weekday: Weekday(rawValue: calendar.component(.weekday, from: date)),
            date: date,
            status: .scheduled,
            workoutType: .weights,
            orderIndex: 0,
            durationMinutes: 45,
            exercises: [
                PlannedExercise(
                    exerciseID: "0001",
                    name: "Bench",
                    bodyPart: "Chest",
                    equipment: "Barbell",
                    targetMuscle: "Pectorals",
                    secondaryMuscles: [],
                    imageURL: nil,
                    order: 0,
                    sets: 3,
                    reps: 10
                ),
            ]
        )
        return GeneratedPlan(
            goal: .buildMuscle,
            scheduleType: .scheduled,
            sessionDurationMinutes: 45,
            startDate: monday,
            weeks: [PlanWeek(number: 1, sessions: [session])],
            seed: 1
        )
    }

    private func makeProfile(startDate: Date) -> RestoredProfile {
        RestoredProfile(
            displayName: "Alex",
            goal: .buildMuscle,
            experience: .oneToSixMonths,
            regularity: .onAndOff,
            location: .commercialGym,
            injuries: [:],
            trainingDays: [.monday, .wednesday, .friday],
            scheduleType: .scheduled,
            planLengthWeeks: 1,
            sessionDuration: .fortyFiveMinutes,
            age: 28,
            gender: .male,
            heightCM: 178,
            weightKG: 75,
            allergies: [],
            equipment: ["Barbell"],
            startDate: startDate,
            maintenanceCalories: 2400,
            units: "metric",
            onboardingCompleted: true
        )
    }

    private func makeStore(
        plan: GeneratedPlan,
        syncEngine: MockSyncEngine
    ) -> PlanStore {
        let store = PlanStore(
            mutationService: MockPlanMutationService(),
            syncEngine: syncEngine
        )
        store.configure(
            from: RestoredUserState(
                profile: makeProfile(startDate: plan.startDate),
                plan: plan
            )
        )
        return store
    }

    private func seededSession(
        repo: SwiftDataWorkoutSessionRepository,
        planWorkoutId: UUID,
        notes: String? = "Felt strong",
        accumulatedSeconds: Int = 1_200,
        reps: [Int] = [10, 8, 6]
    ) throws -> WorkoutSessionRecord {
        let userId = UUID()
        let session = try repo.startOrResume(planWorkoutId: planWorkoutId, userId: userId)
        session.accumulatedActiveSeconds = accumulatedSeconds
        session.notes = notes
        if let notes {
            try repo.updateWorkoutNotes(sessionId: session.id, notes: notes)
        }
        let exerciseId = UUID()
        for (index, repCount) in reps.enumerated() {
            _ = try repo.upsertSetLog(
                sessionId: session.id,
                id: nil,
                workoutExerciseId: exerciseId,
                exerciseName: "Bench",
                setNumber: index + 1,
                reps: repCount,
                weightKg: 60,
                durationSeconds: nil
            )
        }
        return try #require(try repo.session(id: session.id))
    }

    @Test("Load shows name, date from startedAt, planned vs actual, total reps, prefills notes")
    func loadSummaryFields() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let plan = makeScheduledPlan()
        let target = try #require(plan.weeks.first?.sessions.first)
        let session = try seededSession(repo: repo, planWorkoutId: target.id)
        let sync = MockSyncEngine()
        sync.flushOnEnqueue = false
        let store = makeStore(plan: plan, syncEngine: sync)

        let viewModel = WorkoutCompletionViewModel(
            planWorkoutID: target.id,
            workoutSessionID: session.id,
            elapsedSecondsHint: 999,
            repository: repo,
            healthWriter: MockWorkoutHealthWriter()
        )
        viewModel.load(using: store)

        #expect(viewModel.workoutName == "Push")
        #expect(viewModel.plannedDurationMinutes == 45)
        #expect(viewModel.actualDurationSeconds == 1_200)
        #expect(viewModel.totalReps == 24)
        #expect(viewModel.notesDraft == "Felt strong")
        #expect(Calendar.current.isDate(viewModel.datePerformed, inSameDayAs: session.startedAt))
        #expect(viewModel.syncToAppleHealth == false)
        #expect(viewModel.exerciseResults.count == 1)
        #expect(viewModel.exerciseResults[0].exerciseName == "Bench")
        #expect(viewModel.exerciseResults[0].sets.count == 3)
        #expect(viewModel.setLine(for: viewModel.exerciseResults[0].sets[0]).contains("10 reps"))
        #expect(viewModel.setLine(for: viewModel.exerciseResults[0].sets[0]).contains("60 kg"))
    }

    @Test("Discard deletes the session and leaves the plan workout scheduled; no sync enqueue")
    func discardDeletesSessionLeavesScheduled() async throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let plan = makeScheduledPlan()
        let target = try #require(plan.weeks.first?.sessions.first)
        let session = try seededSession(repo: repo, planWorkoutId: target.id)
        let sessionId = session.id
        let sync = MockSyncEngine()
        sync.flushOnEnqueue = false
        let store = makeStore(plan: plan, syncEngine: sync)

        let viewModel = WorkoutCompletionViewModel(
            planWorkoutID: target.id,
            workoutSessionID: sessionId,
            elapsedSecondsHint: 1_200,
            repository: repo,
            healthWriter: MockWorkoutHealthWriter()
        )
        viewModel.load(using: store)

        await viewModel.discard()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.didFinish)
        #expect(try repo.session(id: sessionId) == nil)
        #expect(PlanMutator.session(withID: target.id, in: try #require(store.plan))?.status == .scheduled)
        #expect(sync.enqueueCalls.isEmpty)
    }

    @Test("Save completes the session, marks plan completed, and enqueues SyncEngine")
    func saveCompletesAndMarksPlan() async throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let plan = makeScheduledPlan()
        let target = try #require(plan.weeks.first?.sessions.first)
        let session = try seededSession(repo: repo, planWorkoutId: target.id)
        let sync = MockSyncEngine()
        sync.flushOnEnqueue = false
        let store = makeStore(plan: plan, syncEngine: sync)
        let health = MockWorkoutHealthWriter()

        let viewModel = WorkoutCompletionViewModel(
            planWorkoutID: target.id,
            workoutSessionID: session.id,
            elapsedSecondsHint: 1_200,
            repository: repo,
            healthWriter: health
        )
        viewModel.load(using: store)
        viewModel.updateNotesDraft("  Finished well  ")

        await viewModel.save(using: store)

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.didSaveLocally)
        #expect(!viewModel.didFinish)
        #expect(health.writeCalls.isEmpty)

        let completed = try #require(try repo.session(id: session.id))
        #expect(!completed.isInProgress)
        #expect(completed.endedAt != nil)
        #expect(completed.durationSeconds == 1_200)
        #expect(completed.notes == "Finished well")
        #expect(completed.syncedToHealth == false)
        #expect(completed.needsSync)
        #expect(PlanMutator.session(withID: target.id, in: try #require(store.plan))?.status == .completed)
        #expect(sync.enqueueCalls == [session.id])

        viewModel.acknowledgeHealthMessageAndFinish()
        #expect(viewModel.didFinish)
    }

    @Test("Save with Health toggle on marks syncedToHealth on success")
    func saveHealthSuccess() async throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let plan = makeScheduledPlan()
        let target = try #require(plan.weeks.first?.sessions.first)
        let session = try seededSession(repo: repo, planWorkoutId: target.id)
        let sync = MockSyncEngine()
        sync.flushOnEnqueue = false
        let store = makeStore(plan: plan, syncEngine: sync)
        let health = MockWorkoutHealthWriter()

        let viewModel = WorkoutCompletionViewModel(
            planWorkoutID: target.id,
            workoutSessionID: session.id,
            elapsedSecondsHint: 1_200,
            repository: repo,
            healthWriter: health
        )
        viewModel.load(using: store)
        viewModel.syncToAppleHealth = true

        await viewModel.save(using: store)

        #expect(viewModel.healthSyncMessage == nil)
        #expect(viewModel.didSaveLocally)
        #expect(!viewModel.didFinish)
        #expect(health.writeCalls.count == 1)
        #expect(health.authorizationRequestCount == 1)
        let completed = try #require(try repo.session(id: session.id))
        #expect(completed.syncedToHealth)
        #expect(completed.needsSync)
        #expect(PlanMutator.session(withID: target.id, in: try #require(store.plan))?.status == .completed)
        #expect(sync.enqueueCalls == [session.id])

        viewModel.acknowledgeHealthMessageAndFinish()
        #expect(viewModel.didFinish)
    }

    @Test("Health write failure leaves syncedToHealth false, soft message, session+plan still saved")
    func saveHealthFailureKeepsLocal() async throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let plan = makeScheduledPlan()
        let target = try #require(plan.weeks.first?.sessions.first)
        let session = try seededSession(repo: repo, planWorkoutId: target.id)
        let sync = MockSyncEngine()
        sync.flushOnEnqueue = false
        let store = makeStore(plan: plan, syncEngine: sync)
        let health = MockWorkoutHealthWriter()
        health.shouldFailNextWrite = true

        let viewModel = WorkoutCompletionViewModel(
            planWorkoutID: target.id,
            workoutSessionID: session.id,
            elapsedSecondsHint: 1_200,
            repository: repo,
            healthWriter: health
        )
        viewModel.load(using: store)
        viewModel.syncToAppleHealth = true

        await viewModel.save(using: store)

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.didSaveLocally)
        #expect(!viewModel.didFinish)
        #expect(viewModel.healthSyncMessage != nil)
        let completed = try #require(try repo.session(id: session.id))
        #expect(!completed.syncedToHealth)
        #expect(completed.endedAt != nil)
        #expect(PlanMutator.session(withID: target.id, in: try #require(store.plan))?.status == .completed)
        #expect(sync.enqueueCalls == [session.id])

        viewModel.acknowledgeHealthMessageAndFinish()
        #expect(viewModel.didFinish)
        #expect(viewModel.healthSyncMessage == nil)
    }

    @Test("Toggle off never calls Health writer")
    func saveToggleOffSkipsHealth() async throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let plan = makeScheduledPlan()
        let target = try #require(plan.weeks.first?.sessions.first)
        let session = try seededSession(repo: repo, planWorkoutId: target.id)
        let sync = MockSyncEngine()
        sync.flushOnEnqueue = false
        let store = makeStore(plan: plan, syncEngine: sync)
        let health = MockWorkoutHealthWriter()

        let viewModel = WorkoutCompletionViewModel(
            planWorkoutID: target.id,
            workoutSessionID: session.id,
            elapsedSecondsHint: 1_200,
            repository: repo,
            healthWriter: health
        )
        viewModel.load(using: store)
        #expect(viewModel.syncToAppleHealth == false)

        await viewModel.save(using: store)

        #expect(health.writeCalls.isEmpty)
        #expect(health.authorizationRequestCount == 0)
        let completed = try #require(try repo.session(id: session.id))
        #expect(!completed.syncedToHealth)
    }
}
