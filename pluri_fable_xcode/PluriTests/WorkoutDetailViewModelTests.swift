import Foundation
import SwiftData
import Testing
@testable import Pluri

/// M4-05/06 — Detail Notes (startOrResume then update) and Skip discard.
@Suite("WorkoutDetailViewModel")
@MainActor
struct WorkoutDetailViewModelTests {

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

    private func makeScheduledPlan() -> GeneratedPlan {
        let calendar = Calendar.current
        var monday = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_752_364_800))
        while calendar.component(.weekday, from: monday) != Weekday.monday.rawValue {
            monday = calendar.date(byAdding: .day, value: 1, to: monday) ?? monday
        }
        let date = calendar.date(byAdding: .day, value: 7, to: monday) ?? monday
        let session = PlannedSession(
            title: "Push",
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

    @Test("Saving notes creates/resumes a session then persists notes")
    func saveNotesStartsSession() throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let planWorkoutId = UUID()
        let userId = UUID()
        let viewModel = WorkoutDetailViewModel(
            sessionID: planWorkoutId,
            repository: repo,
            userIDProvider: { userId }
        )

        viewModel.updateNotesDraft("  Felt strong  ")
        viewModel.saveNotes()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.notesDraft == "Felt strong")
        let session = try #require(try repo.inProgressSession(for: planWorkoutId))
        #expect(session.notes == "Felt strong")
        #expect(session.userId == userId)
    }

    @Test("Saving notes without a user surfaces a gentle missing-user message")
    func saveNotesRequiresUser() {
        let container = try! makeContainer()
        let repo = makeRepository(in: container)
        let viewModel = WorkoutDetailViewModel(
            sessionID: UUID(),
            repository: repo,
            userIDProvider: { nil }
        )

        viewModel.updateNotesDraft("Note")
        viewModel.saveNotes()

        #expect(viewModel.errorMessage == PlanMutationError.missingUser.userFacingMessage)
    }

    @Test("Successful skip discards any local in-progress session")
    func skipDiscardsInProgressSession() async throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let plan = makeScheduledPlan()
        let target = try #require(plan.weeks.first?.sessions.first)
        let userId = UUID()

        _ = try repo.startOrResume(planWorkoutId: target.id, userId: userId)
        #expect(try repo.inProgressSession(for: target.id) != nil)

        let store = PlanStore(mutationService: MockPlanMutationService())
        store.configure(
            from: RestoredUserState(
                profile: RestoredProfile(
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
                    startDate: plan.startDate,
                    maintenanceCalories: 2400,
                    units: "metric",
                    onboardingCompleted: true
                ),
                plan: plan
            )
        )

        let viewModel = WorkoutDetailViewModel(
            sessionID: target.id,
            repository: repo,
            userIDProvider: { userId }
        )

        await viewModel.skip(using: store)

        #expect(viewModel.errorMessage == nil)
        let planAfter = try #require(store.plan)
        let updated = try #require(PlanMutator.session(withID: target.id, in: planAfter))
        #expect(updated.status == .skipped)
        #expect(try repo.inProgressSession(for: target.id) == nil)
    }

    @Test("Unskip restores a skipped workout to scheduled")
    func unskipRestoresScheduledStatus() async throws {
        let container = try makeContainer()
        let repo = makeRepository(in: container)
        let plan = makeScheduledPlan()
        let target = try #require(plan.weeks.first?.sessions.first)
        let store = PlanStore(mutationService: MockPlanMutationService())
        store.configure(
            from: RestoredUserState(
                profile: RestoredProfile(
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
                    startDate: plan.startDate,
                    maintenanceCalories: 2400,
                    units: "metric",
                    onboardingCompleted: true
                ),
                plan: plan
            )
        )
        try await store.skipWorkout(id: target.id)
        let viewModel = WorkoutDetailViewModel(
            sessionID: target.id,
            repository: repo,
            userIDProvider: { UUID() }
        )

        await viewModel.unskip(using: store)

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isUnskipping == false)
        let updatedPlan = try #require(store.plan)
        #expect(PlanMutator.session(withID: target.id, in: updatedPlan)?.status == .scheduled)
    }
}
