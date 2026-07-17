import Testing
import Foundation
@testable import Pluri

/// M2-13 / M2-19 — pure mapper round-trips across representative personas:
/// commercial-gym scheduled, bodyweight + injured flexible, and a home-gym
/// minimal-days returner. Assertions cover identifiers, ordering, dates,
/// enum codes, injuries, equipment, and the hydrated plan structure.
@Suite("OnboardingSyncMapper")
struct OnboardingSyncMapperTests {
    // MARK: - Personas

    /// Alex — commercial gym, scheduled Mon/Wed/Fri, building muscle.
    @MainActor
    private func makeCommercialGymPersona() -> OnboardingAnswers {
        let answers = OnboardingAnswers()
        answers.name = "Alex"
        answers.goal = .buildMuscle
        answers.experience = .oneToSixMonths
        answers.regularity = .onAndOff
        answers.location = .commercialGym
        answers.equipment = ["Dumbbell", "Barbell", "Cable", "Kettlebell"]
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

    /// Maya — bodyweight only, injured (back + neck), flexible schedule,
    /// brand-new to training, losing fat.
    @MainActor
    private func makeBodyweightInjuredPersona() -> OnboardingAnswers {
        let answers = OnboardingAnswers()
        answers.name = "Maya"
        answers.goal = .loseFatToneUp
        answers.experience = .notYet
        answers.regularity = .never
        answers.location = .bodyweight
        answers.equipment = ["Body Weight", "Resistance Band"]
        answers.injuries = [.back: 4, .neck: 2]
        answers.trainingDays = [.tuesday, .thursday]
        answers.scheduleType = .flexible
        answers.planLengthWeeks = 4
        answers.sessionDuration = .thirtyMinutes
        answers.age = 45
        answers.gender = .female
        answers.heightCM = 165
        answers.weightKG = 60
        answers.allergies = ["Shellfish", "Peanuts"]
        answers.startDateOption = .tomorrow
        return answers
    }

    /// Sam — home gym, one chosen training day (clamps to the 2-day floor),
    /// experienced returner chasing general fitness, custom start date.
    @MainActor
    private func makeHomeGymReturnerPersona() -> OnboardingAnswers {
        let answers = OnboardingAnswers()
        answers.name = "Sam"
        answers.goal = .generalFitness
        answers.experience = .twoPlusYears
        answers.regularity = .comingBack
        answers.location = .homeGym
        answers.equipment = ["Dumbbell", "Kettlebell"]
        answers.injuries = [:]
        answers.trainingDays = [.saturday]
        answers.scheduleType = .scheduled
        answers.planLengthWeeks = 8
        answers.sessionDuration = .oneHourThirty
        answers.age = 61
        answers.gender = .other
        answers.heightCM = 172
        answers.weightKG = 82
        answers.allergies = []
        answers.startDateOption = .custom
        answers.customStartDate = Date(timeIntervalSince1970: 1_800_000_000)
        return answers
    }

    @MainActor
    private func generatePlan(for answers: OnboardingAnswers) throws -> GeneratedPlan {
        let input = PlanInput(answers: answers)
        return try PlanEngine.generate(
            input: input,
            catalog: .workoutXPreviewFixtures,
            seed: input.deterministicSeed
        )
    }

    // MARK: - Profile mapping

    @Test("Commercial-gym persona maps to profile CHECK codes")
    @MainActor
    func commercialGymProfileMapping() throws {
        let answers = makeCommercialGymPersona()
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
        #expect(row.equipment == ["Barbell", "Cable", "Dumbbell", "Kettlebell"])
        #expect(row.allergies == ["Peanuts"])
        #expect(row.gender == "male")
        #expect(row.sessionMinutes == 60)
        #expect(row.programWeeks == 6)
        #expect(row.maintenanceCalories == answers.maintenanceCalories)
        #expect(row.startDate == DatabaseCodeMappings.dateString(answers.resolvedStartDate))
    }

    @Test("Bodyweight injured persona maps injuries sorted and flexible schedule")
    @MainActor
    func bodyweightInjuredProfileMapping() throws {
        let answers = makeBodyweightInjuredPersona()

        let row = try OnboardingSyncMapper.profileRow(userID: UUID(), answers: answers)

        #expect(row.displayName == "Maya")
        #expect(row.goal == "get_lean")
        #expect(row.trainingExperience == "not_yet")
        #expect(row.trainingRegularity == "never")
        #expect(row.workoutLocation == "bodyweight")
        #expect(row.scheduleType == "flexible")
        // Injuries serialize sorted by area for deterministic rows.
        #expect(row.injuries == [InjuryJSON(area: "Back", pain: 4), InjuryJSON(area: "Neck", pain: 2)])
        #expect(row.workoutDays == ["tue", "thu"])
        #expect(row.daysPerWeek == 2)
        #expect(row.equipment == ["Body Weight", "Resistance Band"])
        #expect(row.allergies == ["Peanuts", "Shellfish"])
        #expect(row.gender == "female")
        #expect(row.sessionMinutes == 30)
        #expect(row.programWeeks == 4)
        #expect(row.startDate == DatabaseCodeMappings.dateString(answers.resolvedStartDate))
    }

    @Test("Home-gym returner clamps a single training day to the 2-day floor")
    @MainActor
    func homeGymReturnerProfileMapping() throws {
        let answers = makeHomeGymReturnerPersona()

        let row = try OnboardingSyncMapper.profileRow(userID: UUID(), answers: answers)

        #expect(row.displayName == "Sam")
        #expect(row.goal == "overall_fitness")
        #expect(row.trainingExperience == "2_plus_years")
        #expect(row.trainingRegularity == "returning")
        #expect(row.workoutLocation == "home_gym")
        #expect(row.workoutDays == ["sat"])
        // SPEC §3.2 Q8 range is 2–6 days; a single chosen day clamps up.
        #expect(row.daysPerWeek == 2)
        #expect(row.injuries.isEmpty)
        #expect(row.allergies.isEmpty)
        #expect(row.gender == "other")
        #expect(row.sessionMinutes == 90)
        #expect(row.programWeeks == 8)
        #expect(row.startDate == DatabaseCodeMappings.dateString(answers.resolvedStartDate))
    }

    @Test("Incomplete questionnaire answers refuse to map")
    @MainActor
    func incompleteAnswersThrow() {
        let answers = OnboardingAnswers()
        answers.name = "Nobody"
        #expect(throws: PluriSyncError.incompleteAnswers) {
            try OnboardingSyncMapper.profileRow(userID: UUID(), answers: answers)
        }
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

    // MARK: - Plan tree mapping

    @Test("Scheduled plan maps into ordered, dated plan tree rows")
    @MainActor
    func scheduledPlanTreeMapping() throws {
        let answers = makeCommercialGymPersona()
        let plan = try generatePlan(for: answers)
        let userID = UUID()

        let tree = OnboardingSyncMapper.planTree(userID: userID, plan: plan)

        #expect(tree.plan.id == plan.id)
        #expect(tree.plan.userId == userID)
        #expect(tree.plan.goal == "build_muscle")
        #expect(tree.plan.scheduleType == "scheduled")
        #expect(tree.plan.status == "active")
        #expect(tree.plan.weeks == plan.weekCount)
        #expect(tree.plan.startDate == DatabaseCodeMappings.dateString(plan.startDate))
        #expect(tree.plan.endDate == DatabaseCodeMappings.dateString(plan.endDate))

        // Workouts: 1:1 with sessions, globally ordered, week numbers ascending.
        #expect(tree.workouts.count == plan.totalSessions)
        #expect(tree.workouts.map(\.orderIndex) == Array(0..<tree.workouts.count))
        #expect(tree.workouts.map(\.weekNumber) == tree.workouts.map(\.weekNumber).sorted())
        #expect(Set(tree.workouts.map(\.weekNumber)) == Set(1...plan.weekCount))
        #expect(tree.workouts.map(\.id) == plan.weeks.flatMap { $0.sessions.map(\.id) })
        #expect(tree.workouts.allSatisfy { $0.planId == plan.id })
        #expect(tree.workouts.allSatisfy { $0.workoutType == "weights" })
        #expect(tree.workouts.allSatisfy { $0.status == "scheduled" })

        // M3-03: rows carry the session's own metadata, not reinvented values.
        let sessions = plan.weeks.flatMap(\.sessions)
        #expect(tree.workouts.map(\.orderIndex) == sessions.map(\.orderIndex))
        #expect(tree.workouts.map(\.durationMinutes) == sessions.map {
            PlannedSession.clampedDuration($0.durationMinutes)
        })
        #expect(tree.workouts.map(\.color) == sessions.map(\.color))

        // Scheduled persona: every session is pinned to a chosen day with a date.
        #expect(tree.workouts.allSatisfy { ["mon", "wed", "fri"].contains($0.scheduledDay ?? "") })
        #expect(tree.workouts.allSatisfy { $0.scheduledDate != nil })

        // Exercises: keyed to real workouts, per-workout order starts at 0 and ascends.
        #expect(!tree.exercises.isEmpty)
        let workoutIDs = Set(tree.workouts.map(\.id))
        #expect(tree.exercises.allSatisfy { workoutIDs.contains($0.planWorkoutId) })
        let byWorkout = Dictionary(grouping: tree.exercises, by: \.planWorkoutId)
        for exercises in byWorkout.values {
            #expect(exercises.map(\.orderIndex).sorted() == Array(0..<exercises.count))
        }
    }

    @Test("Flexible bodyweight plan maps with nil scheduling and injury-safe exercises")
    @MainActor
    func flexiblePlanTreeMapping() throws {
        let answers = makeBodyweightInjuredPersona()
        let plan = try generatePlan(for: answers)

        let tree = OnboardingSyncMapper.planTree(userID: UUID(), plan: plan)

        #expect(tree.plan.goal == "get_lean")
        #expect(tree.plan.scheduleType == "flexible")
        #expect(tree.plan.weeks == 4)

        // Flexible plans carry no pinned day or date (SPEC §3.2 Q9).
        #expect(tree.workouts.allSatisfy { $0.scheduledDay == nil })
        #expect(tree.workouts.allSatisfy { $0.scheduledDate == nil })
        #expect(tree.workouts.map(\.orderIndex) == Array(0..<tree.workouts.count))

        // Injured areas (Back, Neck) never appear in cached exercise metadata.
        #expect(!tree.exercises.isEmpty)
        #expect(tree.exercises.allSatisfy { $0.cachedMetadata.bodyPart != "Back" })
        #expect(tree.exercises.allSatisfy { $0.cachedMetadata.bodyPart != "Neck" })
    }

    // MARK: - Round-trips

    @Test(
        "Round-trips profile rows through hydrate for every persona",
        arguments: [PersonaKind.commercialGym, .bodyweightInjured, .homeGymReturner]
    )
    @MainActor
    func profileRoundTrip(persona: PersonaKind) throws {
        let answers = makeAnswers(for: persona)
        let row = try OnboardingSyncMapper.profileRow(userID: UUID(), answers: answers)
        let restored = OnboardingSyncMapper.hydrateProfile(from: row)

        #expect(restored.displayName == answers.name)
        #expect(restored.goal == answers.goal)
        #expect(restored.experience == answers.experience)
        #expect(restored.regularity == answers.regularity)
        #expect(restored.location == answers.location)
        #expect(restored.injuries == answers.injuries)
        #expect(restored.trainingDays == answers.trainingDays)
        #expect(restored.scheduleType == answers.scheduleType)
        #expect(restored.planLengthWeeks == answers.planLengthWeeks)
        #expect(restored.sessionDuration == answers.sessionDuration)
        #expect(restored.age == answers.age)
        #expect(restored.gender == answers.gender)
        #expect(restored.allergies == answers.allergies)
        #expect(restored.equipment == answers.equipment)
        #expect(restored.maintenanceCalories == answers.maintenanceCalories)
        #expect(restored.onboardingCompleted)
        let restoredStartDate = try #require(restored.startDate)
        #expect(
            DatabaseCodeMappings.dateString(restoredStartDate)
                == DatabaseCodeMappings.dateString(answers.resolvedStartDate)
        )
    }

    @Test(
        "Round-trips full plan trees through hydrate for every persona",
        arguments: [PersonaKind.commercialGym, .bodyweightInjured, .homeGymReturner]
    )
    @MainActor
    func planRoundTrip(persona: PersonaKind) throws {
        let answers = makeAnswers(for: persona)
        let plan = try generatePlan(for: answers)
        let tree = OnboardingSyncMapper.planTree(userID: UUID(), plan: plan)

        let restored = try #require(
            OnboardingSyncMapper.hydratePlan(
                plan: tree.plan,
                workouts: tree.workouts,
                exercises: tree.exercises
            )
        )

        #expect(restored.id == plan.id)
        #expect(restored.goal == plan.goal)
        #expect(restored.scheduleType == plan.scheduleType)
        #expect(restored.weekCount == plan.weekCount)
        #expect(restored.totalSessions == plan.totalSessions)
        #expect(restored.weeks.map(\.number) == plan.weeks.map(\.number))

        // M3-03: plan-level metadata survives the round-trip.
        #expect(restored.name == (plan.name ?? plan.goal.rawValue))
        #expect(restored.status == plan.status)
        #expect(
            DatabaseCodeMappings.dateString(restored.endDate)
                == DatabaseCodeMappings.dateString(plan.endDate)
        )

        for (restoredWeek, originalWeek) in zip(restored.weeks, plan.weeks) {
            #expect(restoredWeek.sessions.map(\.id) == originalWeek.sessions.map(\.id))
            for (restoredSession, originalSession) in zip(restoredWeek.sessions, originalWeek.sessions) {
                #expect(restoredSession.title == originalSession.title)
                #expect(restoredSession.weekday == originalSession.weekday)
                #expect(
                    restoredSession.date.map(DatabaseCodeMappings.dateString)
                        == originalSession.date.map(DatabaseCodeMappings.dateString)
                )

                // M3-03: workout metadata survives the round-trip.
                #expect(restoredSession.status == originalSession.status)
                #expect(restoredSession.workoutType == originalSession.workoutType)
                #expect(restoredSession.color == originalSession.color)
                #expect(restoredSession.orderIndex == originalSession.orderIndex)
                #expect(
                    restoredSession.durationMinutes
                        == PlannedSession.clampedDuration(originalSession.durationMinutes)
                )

                #expect(restoredSession.exercises.map(\.id) == originalSession.exercises.map(\.id))
                #expect(
                    restoredSession.exercises.map(\.exerciseID)
                        == originalSession.exercises.map(\.exerciseID)
                )
                #expect(restoredSession.exercises.map(\.order) == originalSession.exercises.map(\.order))
                #expect(restoredSession.exercises.map(\.sets) == originalSession.exercises.map(\.sets))
                #expect(restoredSession.exercises.map(\.reps) == originalSession.exercises.map(\.reps))
                #expect(restoredSession.exercises.map(\.name) == originalSession.exercises.map(\.name))
            }
        }
    }

    @Test("Progress statuses, colors, and plan metadata survive hydrate")
    @MainActor
    func progressMetadataRoundTrip() throws {
        let answers = makeCommercialGymPersona()
        let plan = try generatePlan(for: answers)
        var tree = OnboardingSyncMapper.planTree(userID: UUID(), plan: plan)

        // Simulate mid-plan progress the way the DB would hold it.
        tree.workouts[0].status = "completed"
        tree.workouts[1].status = "skipped"
        tree.workouts[2].color = "brand/orange"
        tree.plan.status = "completed"
        tree.plan.name = "Summer Strength"

        let restored = try #require(
            OnboardingSyncMapper.hydratePlan(
                plan: tree.plan,
                workouts: tree.workouts,
                exercises: tree.exercises
            )
        )

        let sessions = restored.weeks.flatMap(\.sessions)
        let byID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        #expect(byID[tree.workouts[0].id]?.status == .completed)
        #expect(byID[tree.workouts[1].id]?.status == .skipped)
        #expect(byID[tree.workouts[2].id]?.color == "brand/orange")
        #expect(sessions.count(where: { $0.status == .scheduled }) == sessions.count - 2)
        #expect(restored.status == .completed)
        #expect(restored.name == "Summer Strength")
    }

    @Test("Hydrate preserves the declared week count when trailing weeks are empty")
    @MainActor
    func hydratePreservesDeclaredWeekCount() throws {
        let answers = makeCommercialGymPersona()
        let plan = try generatePlan(for: answers)
        let tree = OnboardingSyncMapper.planTree(userID: UUID(), plan: plan)

        // Drop every week-6 workout: the plan row still declares 6 weeks.
        let lastWeekIDs = Set(tree.workouts.filter { $0.weekNumber == 6 }.map(\.id))
        let trimmedWorkouts = tree.workouts.filter { !lastWeekIDs.contains($0.id) }
        let trimmedExercises = tree.exercises.filter { !lastWeekIDs.contains($0.planWorkoutId) }

        let restored = try #require(
            OnboardingSyncMapper.hydratePlan(
                plan: tree.plan,
                workouts: trimmedWorkouts,
                exercises: trimmedExercises
            )
        )

        #expect(restored.weekCount == 6)
        #expect(restored.weeks.last?.sessions.isEmpty == true)
    }

    // MARK: - Persona plumbing

    enum PersonaKind: CaseIterable {
        case commercialGym
        case bodyweightInjured
        case homeGymReturner
    }

    @MainActor
    private func makeAnswers(for persona: PersonaKind) -> OnboardingAnswers {
        switch persona {
        case .commercialGym: makeCommercialGymPersona()
        case .bodyweightInjured: makeBodyweightInjuredPersona()
        case .homeGymReturner: makeHomeGymReturnerPersona()
        }
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
