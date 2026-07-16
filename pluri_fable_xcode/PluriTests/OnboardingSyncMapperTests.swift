import Testing
import Foundation
@testable import Pluri

@Suite("OnboardingSyncMapper")
struct OnboardingSyncMapperTests {
    @Test("Maps onboarding answers to profile CHECK codes")
    @MainActor
    func profileMapping() throws {
        let answers = makeCompleteAnswers()
        let userID = UUID()

        let row = try OnboardingSyncMapper.profileRow(userID: userID, answers: answers)

        #expect(row.id == userID)
        #expect(row.displayName == "Alex")
        #expect(row.goal == "build_muscle")
        #expect(row.trainingExperience == "1_6_months")
        #expect(row.trainingRegularity == "on_and_off")
        #expect(row.workoutLocation == "commercial_gym")
        #expect(row.scheduleType == "scheduled")
        #expect(row.units == "metric")
        #expect(row.onboardingCompleted == true)
        #expect(row.workoutDays == ["mon", "wed", "fri"])
        #expect(row.daysPerWeek == 3)
        #expect(row.injuries == [InjuryJSON(area: "Back", pain: 3)])
        #expect(row.equipment.contains("Dumbbell"))
        #expect(row.allergies.contains("Peanuts"))
        #expect(row.gender == "male")
        #expect(row.sessionMinutes == 60)
        #expect(row.programWeeks == 6)
    }

    @Test("Goal codes cover all four app goals")
    func goalCodes() {
        #expect(DatabaseCodeMappings.goalCode(.buildMuscle) == "build_muscle")
        #expect(DatabaseCodeMappings.goalCode(.getStronger) == "build_strength")
        #expect(DatabaseCodeMappings.goalCode(.loseFatToneUp) == "get_lean")
        #expect(DatabaseCodeMappings.goalCode(.generalFitness) == "overall_fitness")
        #expect(DatabaseCodeMappings.goal(from: "lose_weight") == .loseFatToneUp)
        #expect(DatabaseCodeMappings.goal(from: "get_in_shape") == .generalFitness)
    }

    @Test("Maps GeneratedPlan into plans / workouts / exercises rows")
    @MainActor
    func planTreeMapping() throws {
        let answers = makeCompleteAnswers()
        let input = PlanInput(answers: answers)
        let plan = try PlanEngine.generate(
            input: input,
            catalog: .workoutXPreviewFixtures,
            seed: input.deterministicSeed
        )
        let userID = UUID()

        let tree = OnboardingSyncMapper.planTree(userID: userID, plan: plan)

        #expect(tree.plan.id == plan.id)
        #expect(tree.plan.userId == userID)
        #expect(tree.plan.goal == "build_muscle")
        #expect(tree.plan.scheduleType == "scheduled")
        #expect(tree.plan.status == "active")
        #expect(tree.plan.weeks == plan.weekCount)
        #expect(tree.workouts.count == plan.totalSessions)
        #expect(!tree.exercises.isEmpty)
        #expect(tree.workouts.allSatisfy { $0.workoutType == "weights" })
        #expect(tree.workouts.allSatisfy { $0.status == "scheduled" })
        if let first = tree.workouts.first {
            #expect(first.scheduledDay == "mon" || first.scheduledDay == "wed" || first.scheduledDay == "fri")
        }
    }

    @Test("Round-trips profile row through hydrate")
    @MainActor
    func profileRoundTrip() throws {
        let answers = makeCompleteAnswers()
        let row = try OnboardingSyncMapper.profileRow(userID: UUID(), answers: answers)
        let restored = OnboardingSyncMapper.hydrateProfile(from: row)

        #expect(restored.displayName == "Alex")
        #expect(restored.goal == .buildMuscle)
        #expect(restored.experience == .oneToSixMonths)
        #expect(restored.regularity == .onAndOff)
        #expect(restored.location == .commercialGym)
        #expect(restored.injuries[.back] == 3)
        #expect(restored.trainingDays == [.monday, .wednesday, .friday])
        #expect(restored.scheduleType == .scheduled)
    }

    @Test("Round-trips plan tree through hydrate")
    @MainActor
    func planRoundTrip() throws {
        let answers = makeCompleteAnswers()
        let input = PlanInput(answers: answers)
        let plan = try PlanEngine.generate(
            input: input,
            catalog: .workoutXPreviewFixtures,
            seed: input.deterministicSeed
        )
        let tree = OnboardingSyncMapper.planTree(userID: UUID(), plan: plan)
        let restored = OnboardingSyncMapper.hydratePlan(
            plan: tree.plan,
            workouts: tree.workouts,
            exercises: tree.exercises
        )

        #expect(restored != nil)
        #expect(restored?.id == plan.id)
        #expect(restored?.goal == plan.goal)
        #expect(restored?.weekCount == plan.weekCount)
        #expect(restored?.totalSessions == plan.totalSessions)
    }

    @MainActor
    private func makeCompleteAnswers() -> OnboardingAnswers {
        let answers = OnboardingAnswers()
        answers.name = "Alex"
        answers.goal = .buildMuscle
        answers.experience = .oneToSixMonths
        answers.regularity = .onAndOff
        answers.location = .commercialGym
        answers.equipment = ["Dumbbell", "Barbell"]
        answers.injuries = [.back: 3]
        answers.trainingDays = [.monday, .wednesday, .friday]
        answers.scheduleType = .scheduled
        answers.planLengthWeeks = 6
        answers.sessionDuration = .oneHour
        answers.age = 28
        answers.gender = .male
        answers.heightCM = 178
        answers.weightKG = 75
        answers.allergies = ["Peanuts"]
        answers.startDateOption = .today
        return answers
    }
}

@Suite("MockOnboardingFlushService")
struct OnboardingFlushServiceTests {
    @MainActor
    private func makeAnswersAndPlan() throws -> (OnboardingAnswers, GeneratedPlan) {
        let answers = OnboardingAnswers()
        answers.name = "Alex"
        answers.goal = .buildMuscle
        answers.experience = .oneToSixMonths
        answers.regularity = .onAndOff
        answers.location = .commercialGym
        answers.equipment = Set(EquipmentCatalog.all)
        answers.trainingDays = [.monday, .wednesday, .friday]
        answers.scheduleType = .scheduled
        answers.planLengthWeeks = 6
        answers.sessionDuration = .oneHour
        answers.age = 28
        answers.gender = .male
        answers.heightCM = 178
        answers.weightKG = 75
        let input = PlanInput(answers: answers)
        let plan = try PlanEngine.generate(
            input: input,
            catalog: .workoutXPreviewFixtures,
            seed: input.deterministicSeed
        )
        return (answers, plan)
    }

    @Test("Flush succeeds and records ids")
    @MainActor
    func flushSucceeds() async throws {
        let (answers, plan) = try makeAnswersAndPlan()
        let flush = MockOnboardingFlushService()
        let userID = UUID()

        try await flush.flush(userID: userID, answers: answers, plan: plan)

        #expect(flush.flushCount == 1)
        #expect(flush.lastUserID == userID)
        #expect(flush.lastPlanID == plan.id)
    }

    @Test("Flush failure propagates typed error without clearing answers")
    @MainActor
    func flushFailure() async throws {
        let (answers, plan) = try makeAnswersAndPlan()
        let flush = MockOnboardingFlushService()
        flush.nextError = .networkUnavailable

        await #expect(throws: PluriSyncError.networkUnavailable) {
            try await flush.flush(userID: UUID(), answers: answers, plan: plan)
        }
        #expect(flush.flushCount == 0)
        #expect(answers.name == "Alex")
    }
}

@Suite("MockRemotePlanRestoreService")
struct RemotePlanRestoreTests {
    @Test("Restore returns hydrated state")
    @MainActor
    func restoreReturnsState() async throws {
        let restore = MockRemotePlanRestoreService()
        let profile = RestoredProfile(
            displayName: "Sam",
            goal: .getStronger,
            experience: .oneToTwoYears,
            regularity: .regularly,
            location: .smallGym,
            injuries: [:],
            trainingDays: [.monday],
            scheduleType: .flexible,
            planLengthWeeks: 8,
            sessionDuration: .fortyFiveMinutes,
            age: 30,
            gender: .female,
            heightCM: 165,
            weightKG: 60,
            allergies: [],
            equipment: ["Dumbbell"],
            startDate: .now,
            maintenanceCalories: 1800,
            units: "metric",
            onboardingCompleted: true
        )
        restore.result = RestoredUserState(profile: profile, plan: nil)

        let state = try await restore.restore(userID: UUID())
        #expect(state?.profile.displayName == "Sam")
        #expect(restore.restoreCount == 1)
    }
}
