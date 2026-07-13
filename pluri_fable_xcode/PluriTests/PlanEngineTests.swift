import Foundation
import Testing
@testable import pluri_fable_xcode

/// M1-17 — persona-driven tests for the deterministic `PlanEngine` (M1-16).
///
/// Each representative persona (beginner / bodyweight / injured / commercial
/// gym) must produce a plan that uses only the user's equipment, avoids
/// injured body areas, and has sane session lengths — plus the engine must be
/// deterministic given a seed.
@Suite("PlanEngine")
struct PlanEngineTests {

    // MARK: Fixtures

    /// A broad synthetic catalog: one exercise for every (body part × equipment)
    /// pair, including a `"Cardio"` body part (which v1 must exclude) and one
    /// row using the WorkoutX comma punctuation (`"Dumbbell, Exercise Ball"`)
    /// to exercise the equipment-normalization reconciliation.
    static func makeCatalog() -> [Exercise] {
        let bodyParts = [
            "Back", "Chest", "Lower Arms", "Lower Legs", "Neck",
            "Shoulders", "Upper Arms", "Upper Legs", "Waist", "Cardio",
        ]
        let equipment = [
            "Body Weight", "Barbell", "Dumbbell", "Cable",
            "Kettlebell", "Resistance Band", "Dumbbell, Exercise Ball",
        ]
        var result: [Exercise] = []
        var counter = 0
        for bodyPart in bodyParts {
            for item in equipment {
                counter += 1
                result.append(
                    Exercise(
                        id: String(format: "%04d", counter),
                        name: "\(bodyPart) via \(item)",
                        bodyPart: bodyPart,
                        equipment: item,
                        targetMuscle: "\(bodyPart) Muscle",
                        secondaryMuscles: [],
                        instructions: ["Do the \(bodyPart) exercise."],
                        imageURL: nil,
                        videoURL: nil
                    )
                )
            }
        }
        return result
    }

    static func makeInput(
        goal: Goal = .generalFitness,
        experience: ExperienceLevel = .notYet,
        equipment: Set<String>,
        injuries: [BodyArea: Int] = [:],
        trainingDays: [Weekday] = [.monday, .wednesday, .friday],
        scheduleType: ScheduleType = .scheduled,
        planLengthWeeks: Int = 6,
        sessionDurationMinutes: Int = 60
    ) -> PlanInput {
        PlanInput(
            goal: goal,
            experience: experience,
            regularity: nil,
            equipment: equipment,
            injuries: injuries,
            trainingDays: trainingDays,
            scheduleType: scheduleType,
            planLengthWeeks: planLengthWeeks,
            sessionDurationMinutes: sessionDurationMinutes,
            startDate: Date(timeIntervalSince1970: 1_752_364_800) // fixed for determinism
        )
    }

    /// Every planned exercise across the whole plan.
    static func allPlanned(_ plan: GeneratedPlan) -> [PlannedExercise] {
        plan.weeks.flatMap { $0.sessions.flatMap(\.exercises) }
    }

    // MARK: Structure

    @Test("Plan has the requested weeks and one session per training day")
    func planStructureMatchesInput() throws {
        let input = Self.makeInput(equipment: Set(EquipmentCatalog.all))
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 42)

        #expect(plan.weekCount == 6)
        for week in plan.weeks {
            #expect(week.sessions.count == 3)
        }
    }

    @Test("Every session has a sane number of exercises (3–8)")
    func sessionLengthsAreSane() throws {
        let input = Self.makeInput(equipment: Set(EquipmentCatalog.all), sessionDurationMinutes: 60)
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 7)

        for session in plan.weeks.flatMap(\.sessions) {
            #expect(session.exercises.count >= PlanEngine.minExercisesPerSession)
            #expect(session.exercises.count <= PlanEngine.maxExercisesPerSession)
            #expect(session.estimatedMinutes > 0)
        }
    }

    @Test(
        "Exercises-per-session fits the chosen duration",
        arguments: [(30, 4), (45, 6), (60, 8), (90, 8)]
    )
    func exercisesPerSessionFitsDuration(minutes: Int, expected: Int) {
        #expect(PlanEngine.exercisesPerSession(forDurationMinutes: minutes) == expected)
    }

    // MARK: Persona — commercial gym

    @Test("Commercial-gym plan never uses equipment outside the user's selection")
    func commercialGymUsesOnlySelectedEquipment() throws {
        let selection = Set(EquipmentCatalog.all)
        let input = Self.makeInput(equipment: selection)
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 1)

        let allowed = EquipmentMatcher.normalizedKeys(for: selection)
        for exercise in Self.allPlanned(plan) {
            #expect(EquipmentMatcher.isAvailable(exercise.equipment, in: allowed))
        }
    }

    @Test("No plan ever includes Cardio body-part exercises in v1")
    func cardioIsExcluded() throws {
        let input = Self.makeInput(equipment: Set(EquipmentCatalog.all))
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 99)
        #expect(Self.allPlanned(plan).allSatisfy { $0.bodyPart != "Cardio" })
    }

    // MARK: Persona — bodyweight

    @Test("Bodyweight plan uses only body-weight equipment")
    func bodyweightUsesOnlyBodyweight() throws {
        let input = Self.makeInput(equipment: ["Body Weight"])
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 3)

        for exercise in Self.allPlanned(plan) {
            #expect(EquipmentMatcher.normalized(exercise.equipment) == "bodyweight")
        }
    }

    // MARK: Persona — injured

    @Test("Injured areas are excluded from the whole plan")
    func injuredAreasAreExcluded() throws {
        let injuries: [BodyArea: Int] = [.back: 5, .shoulders: 2, .neck: 3]
        let input = Self.makeInput(equipment: Set(EquipmentCatalog.all), injuries: injuries)
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 11)

        let excluded = Set(injuries.keys.map(\.rawValue))
        for exercise in Self.allPlanned(plan) {
            #expect(!excluded.contains(exercise.bodyPart))
        }
    }

    // MARK: Persona — beginner

    @Test("Beginner / general-fitness week 1 uses the base 3×10 target")
    func beginnerBaseSetsReps() throws {
        let input = Self.makeInput(goal: .generalFitness, equipment: Set(EquipmentCatalog.all))
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 5)

        let firstWeek = try #require(plan.weeks.first)
        for exercise in firstWeek.sessions.flatMap(\.exercises) {
            #expect(exercise.sets == 3)
            #expect(exercise.reps == 10)
        }
    }

    // MARK: Progression

    @Test("Progression ramps reps for three weeks, then adds a set")
    func progressionRampsRepsThenSets() {
        let base = PlanEngine.baseSetsReps(goal: .buildMuscle) // (3, 10)
        #expect(PlanEngine.progression(base: base, week: 1) == (3, 10))
        #expect(PlanEngine.progression(base: base, week: 2) == (3, 11))
        #expect(PlanEngine.progression(base: base, week: 4) == (3, 13))
        #expect(PlanEngine.progression(base: base, week: 5) == (4, 13))
    }

    @Test("Goal drives the base rep scheme")
    func goalDrivesBaseScheme() {
        #expect(PlanEngine.baseSetsReps(goal: .getStronger) == (4, 5))
        #expect(PlanEngine.baseSetsReps(goal: .buildMuscle) == (3, 10))
        #expect(PlanEngine.baseSetsReps(goal: .loseFatToneUp) == (3, 12))
        #expect(PlanEngine.baseSetsReps(goal: .generalFitness) == (3, 10))
    }

    // MARK: Scheduling

    @Test("Scheduled sessions land on the chosen weekdays")
    func scheduledSessionsLandOnChosenWeekdays() throws {
        let days: [Weekday] = [.monday, .wednesday, .friday]
        let input = Self.makeInput(equipment: Set(EquipmentCatalog.all), trainingDays: days, scheduleType: .scheduled)
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 8)

        let calendar = Calendar.current
        let chosen = Set(days.map(\.rawValue))
        for session in plan.weeks.flatMap(\.sessions) {
            let weekday = try #require(session.weekday)
            #expect(chosen.contains(weekday.rawValue))
            let date = try #require(session.date)
            #expect(calendar.component(.weekday, from: date) == weekday.rawValue)
        }
    }

    @Test("Flexible plans carry no fixed weekday or date")
    func flexiblePlansHaveNoWeekday() throws {
        let input = Self.makeInput(equipment: Set(EquipmentCatalog.all), scheduleType: .flexible)
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 8)

        for session in plan.weeks.flatMap(\.sessions) {
            #expect(session.weekday == nil)
            #expect(session.date == nil)
        }
    }

    // MARK: Determinism

    @Test("Same input and seed produce an identical plan")
    func deterministicForSameSeed() throws {
        let input = Self.makeInput(equipment: Set(EquipmentCatalog.all))
        let catalog = Self.makeCatalog()
        let first = try PlanEngine.generate(input: input, catalog: catalog, seed: 1234)
        let second = try PlanEngine.generate(input: input, catalog: catalog, seed: 1234)

        let firstIDs = Self.allPlanned(first).map(\.exerciseID)
        let secondIDs = Self.allPlanned(second).map(\.exerciseID)
        #expect(firstIDs == secondIDs)
        #expect(first.weeks.flatMap(\.sessions).map(\.title) == second.weeks.flatMap(\.sessions).map(\.title))
    }

    @Test("A stable seed is derived from the answers")
    func deterministicSeedIsStable() {
        let input = Self.makeInput(equipment: Set(EquipmentCatalog.all))
        #expect(input.deterministicSeed == input.deterministicSeed)
    }

    // MARK: Equipment reconciliation

    @Test("SPEC '+' punctuation matches the catalog's ',' punctuation")
    func equipmentNormalizationBridgesPunctuation() {
        #expect(
            EquipmentMatcher.normalized("Dumbbell + Exercise Ball")
                == EquipmentMatcher.normalized("Dumbbell, Exercise Ball")
        )
        let selection = EquipmentMatcher.normalizedKeys(for: ["Dumbbell + Exercise Ball"])
        #expect(EquipmentMatcher.isAvailable("Dumbbell, Exercise Ball", in: selection))
    }

    @Test("Casing differences don't break equipment matching")
    func equipmentNormalizationIgnoresCase() {
        #expect(
            EquipmentMatcher.normalized("Dumbbell (used as Handles for Deeper Range)")
                == EquipmentMatcher.normalized("Dumbbell (used As Handles For Deeper Range)")
        )
    }

    // MARK: Errors

    @Test("An empty catalog throws emptyCatalog")
    func emptyCatalogThrows() {
        let input = Self.makeInput(equipment: Set(EquipmentCatalog.all))
        #expect(throws: PlanEngineError.emptyCatalog) {
            try PlanEngine.generate(input: input, catalog: [], seed: 1)
        }
    }

    @Test("Equipment that matches nothing throws noEligibleExercises")
    func noEligibleExercisesThrows() {
        let input = Self.makeInput(equipment: ["Nonexistent Machine"])
        #expect(throws: PlanEngineError.noEligibleExercises) {
            try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 1)
        }
    }
}
