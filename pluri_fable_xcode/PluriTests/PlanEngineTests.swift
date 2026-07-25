import Foundation
import Testing
@testable import Pluri

/// Persona-driven tests for the focus-first `PlanEngine` (M1-17 / M3-19).
@Suite("PlanEngine")
struct PlanEngineTests {

    // MARK: Fixtures

    /// Synthetic catalog with real WorkoutX `targetList` muscle names so
    /// focus selection and graded injury rules can be exercised.
    static func makeCatalog() -> [Exercise] {
        struct Spec {
            let bodyPart: String
            let target: String
            let secondary: [String]
            let equipmentOptions: [String]
        }

        let specs: [Spec] = [
            Spec(bodyPart: "Chest", target: "Pectorals", secondary: ["Triceps", "Delts"],
                 equipmentOptions: ["Barbell", "Dumbbell", "Cable", "Body Weight", "Leverage Machine"]),
            Spec(bodyPart: "Back", target: "Lats", secondary: ["Biceps", "Upper Back"],
                 equipmentOptions: ["Barbell", "Dumbbell", "Cable", "Body Weight", "Leverage Machine"]),
            Spec(bodyPart: "Back", target: "Upper Back", secondary: ["Traps", "Biceps"],
                 equipmentOptions: ["Cable", "Dumbbell", "Barbell"]),
            Spec(bodyPart: "Shoulders", target: "Delts", secondary: ["Traps", "Triceps"],
                 equipmentOptions: ["Dumbbell", "Cable", "Barbell", "Leverage Machine", "Body Weight"]),
            Spec(bodyPart: "Upper Arms", target: "Triceps", secondary: ["Delts"],
                 equipmentOptions: ["Dumbbell", "Cable", "Body Weight", "Leverage Machine"]),
            Spec(bodyPart: "Upper Arms", target: "Biceps", secondary: ["Forearms"],
                 equipmentOptions: ["Dumbbell", "Cable", "Barbell", "Body Weight"]),
            Spec(bodyPart: "Upper Legs", target: "Quads", secondary: ["Glutes", "Hamstrings"],
                 equipmentOptions: ["Barbell", "Dumbbell", "Body Weight", "Leverage Machine", "Cable"]),
            Spec(bodyPart: "Upper Legs", target: "Hamstrings", secondary: ["Glutes", "Calves"],
                 equipmentOptions: ["Barbell", "Dumbbell", "Cable", "Leverage Machine"]),
            Spec(bodyPart: "Upper Legs", target: "Glutes", secondary: ["Hamstrings"],
                 equipmentOptions: ["Barbell", "Dumbbell", "Cable", "Body Weight"]),
            Spec(bodyPart: "Lower Legs", target: "Calves", secondary: [],
                 equipmentOptions: ["Body Weight", "Dumbbell", "Leverage Machine"]),
            Spec(bodyPart: "Waist", target: "Abs", secondary: [],
                 equipmentOptions: ["Body Weight", "Cable"]),
            Spec(bodyPart: "Lower Arms", target: "Forearms", secondary: [],
                 equipmentOptions: ["Dumbbell", "Cable"]),
            Spec(bodyPart: "Back", target: "Traps", secondary: ["Delts"],
                 equipmentOptions: ["Dumbbell", "Barbell", "Cable"]),
            Spec(bodyPart: "Cardio", target: "Cardiovascular System", secondary: [],
                 equipmentOptions: ["Body Weight", "Dumbbell"]),
            // WorkoutX comma punctuation — equipment normalization regression.
            Spec(bodyPart: "Chest", target: "Pectorals", secondary: ["Triceps"],
                 equipmentOptions: ["Dumbbell, Exercise Ball"]),
        ]

        var result: [Exercise] = []
        var counter = 0
        for spec in specs {
            for item in spec.equipmentOptions {
                counter += 1
                result.append(
                    Exercise(
                        id: String(format: "%04d", counter),
                        name: "\(spec.target) via \(item)",
                        bodyPart: spec.bodyPart,
                        equipment: item,
                        targetMuscle: spec.target,
                        secondaryMuscles: spec.secondary,
                        instructions: ["Do the \(spec.target) exercise."],
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
            startDate: Date(timeIntervalSince1970: 1_752_364_800)
        )
    }

    static func allPlanned(_ plan: GeneratedPlan) -> [PlannedExercise] {
        plan.weeks.flatMap { $0.sessions.flatMap(\.exercises) }
    }

    // MARK: Structure

    @Test("Plan has the requested weeks and one session per training day")
    func planStructureMatchesInput() throws {
        let input = Self.makeInput(experience: .oneToTwoYears, equipment: Set(EquipmentCatalog.all))
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

    // MARK: Focus-first composition

    @Test("Non-beginner 3-day plan titles follow Push / Pull / Legs")
    func threeDayFocusTitles() throws {
        let input = Self.makeInput(
            experience: .oneToTwoYears,
            equipment: Set(EquipmentCatalog.all)
        )
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 11)
        let week = try #require(plan.weeks.first)
        #expect(week.sessions.map(\.title) == ["Push", "Pull", "Legs"])
        #expect(week.sessions.map(\.focus) == [.push, .pull, .legs])
        #expect(week.sessions.map(\.color) == [
            WorkoutColorToken.brandOrange.rawValue,
            WorkoutColorToken.statusBlue.rawValue,
            WorkoutColorToken.statusGreen.rawValue,
        ])
    }

    @Test("Beginner 3-day plan titles follow Upper / Lower / Full Body")
    func beginnerThreeDayFocusTitles() throws {
        let input = Self.makeInput(
            experience: .notYet,
            equipment: Set(EquipmentCatalog.all)
        )
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 12)
        let week = try #require(plan.weeks.first)
        #expect(week.sessions.map(\.focus) == [.upper, .lower, .fullBodyA])
    }

    @Test("Two-day plan uses Full Body A / B")
    func twoDayFullBodyFocus() throws {
        let input = Self.makeInput(
            equipment: Set(EquipmentCatalog.all),
            trainingDays: [.tuesday, .thursday]
        )
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 4)
        let week = try #require(plan.weeks.first)
        #expect(week.sessions.map(\.focus) == [.fullBodyA, .fullBodyB])
    }

    @Test("Push session is majority primary-target movements")
    func pushSessionMajorityPrimary() throws {
        let input = Self.makeInput(
            experience: .twoPlusYears,
            equipment: Set(EquipmentCatalog.all)
        )
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 15)
        let push = try #require(plan.weeks.first?.sessions.first { $0.focus == .push })
        let primary = Set(SessionFocus.push.primaryMuscles)
        let primaryCount = push.exercises.filter { primary.contains($0.targetMuscle) }.count
        #expect(primaryCount >= push.exercises.count / 2)
    }

    // MARK: Persona — commercial gym / bodyweight / cardio

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

    @Test("Bodyweight plan uses only body-weight equipment")
    func bodyweightUsesOnlyBodyweight() throws {
        let input = Self.makeInput(equipment: ["Body Weight"])
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 3)

        for exercise in Self.allPlanned(plan) {
            #expect(EquipmentMatcher.normalized(exercise.equipment) == "bodyweight")
        }
    }

    // MARK: Graded injury rules (#47)

    @Test("Pain 4–5 hard-excludes injured muscles as primary and secondary")
    func pain45HardExclusion() throws {
        let injuries: [BodyArea: Int] = [.shoulders: 5]
        let input = Self.makeInput(equipment: Set(EquipmentCatalog.all), injuries: injuries)
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 11)

        for exercise in Self.allPlanned(plan) {
            #expect(exercise.targetMuscle != "Delts")
            #expect(!exercise.secondaryMuscles.contains("Delts"))
        }
    }

    @Test("Pain 1–2 avoids injured muscle as primary but may use it as secondary")
    func pain12AllowsSecondaryOnly() throws {
        let injuries: [BodyArea: Int] = [.shoulders: 2]
        let focus = SessionFocus.chestTriceps
        let catalog = Self.makeCatalog()

        let primaryHits = catalog.filter {
            $0.targetMuscle == "Delts"
                && PlanEngine.role(of: $0, in: focus, injuries: injuries) == .primary
        }
        #expect(primaryHits.isEmpty)

        // Chest focus where Delts are secondary: a pec lift listing Delts as
        // secondary involvement is still allowed at pain 2.
        let pec = try #require(catalog.first {
            $0.targetMuscle == "Pectorals" && $0.secondaryMuscles.contains("Delts")
        })
        #expect(PlanEngine.role(of: pec, in: focus, injuries: injuries) == .primary)
    }

    @Test("Pain 3 secondary involvement prefers machine / cable equipment")
    func pain3PrefersSupportedSecondary() {
        let injuries: [BodyArea: Int] = [.shoulders: 3]
        let focus = SessionFocus.chestTriceps
        let freeWeight = Exercise(
            id: "fw",
            name: "DB fly",
            bodyPart: "Chest",
            equipment: "Dumbbell",
            targetMuscle: "Pectorals",
            secondaryMuscles: ["Delts"],
            instructions: [],
            imageURL: nil,
            videoURL: nil
        )
        let machine = Exercise(
            id: "m",
            name: "Cable fly",
            bodyPart: "Chest",
            equipment: "Cable",
            targetMuscle: "Pectorals",
            secondaryMuscles: ["Delts"],
            instructions: [],
            imageURL: nil,
            videoURL: nil
        )
        // Primary pec work: both excluded as primary targeting of Delts? No —
        // target is Pectorals. Secondary Delts at pain 3 on the lift itself:
        // hard secondary on free weight vs allowed on cable when the exercise
        // is selected as a secondary focus slot. For primary pec lifts with
        // Delts as secondaryMuscles at pain 3, role stays primary (injured
        // muscle isn't the target); pain-3 load-cap applies when Delts is the
        // exercise's own target in a secondary slot.
        let deltDumbbell = Exercise(
            id: "dd",
            name: "DB raise",
            bodyPart: "Shoulders",
            equipment: "Dumbbell",
            targetMuscle: "Delts",
            secondaryMuscles: [],
            instructions: [],
            imageURL: nil,
            videoURL: nil
        )
        let deltCable = Exercise(
            id: "dc",
            name: "Cable raise",
            bodyPart: "Shoulders",
            equipment: "Cable",
            targetMuscle: "Delts",
            secondaryMuscles: [],
            instructions: [],
            imageURL: nil,
            videoURL: nil
        )
        #expect(PlanEngine.role(of: freeWeight, in: focus, injuries: injuries) == .primary)
        #expect(PlanEngine.role(of: machine, in: focus, injuries: injuries) == .primary)
        #expect(PlanEngine.role(of: deltDumbbell, in: focus, injuries: injuries) == .excluded)
        #expect(PlanEngine.role(of: deltCable, in: focus, injuries: injuries) == .secondary)
    }

    @Test("Small primary pool falls back to Full Body")
    func smallPoolFallsBackToFullBody() throws {
        // Abs + calves bodyweight only after equipment filter → focused PPL
        // days have fewer than `smallPoolFullBodyThreshold` primary lifts.
        let tinyCatalog = Self.makeCatalog().filter {
            $0.targetMuscle == "Abs" || $0.targetMuscle == "Calves"
        }
        let input = Self.makeInput(
            experience: .twoPlusYears,
            equipment: ["Body Weight"],
            trainingDays: [.monday, .wednesday, .friday]
        )
        #expect(PlanEngine.smallPoolFullBodyThreshold == 3)

        let eligible = PlanEngine.filteredCatalog(tinyCatalog, input: input)
        var rng = SeededGenerator(seed: 1)
        let templates = PlanEngine.buildSessionTemplates(from: eligible, input: input, rng: &rng)
        #expect(templates.allSatisfy { $0.focus.isFullBody })
    }

    // MARK: Progression / scheduling / determinism

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

    @Test("Progression ramps reps for three weeks, then adds a set")
    func progressionRampsRepsThenSets() {
        let base = PlanEngine.baseSetsReps(goal: .buildMuscle)
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

    @Test(
        "Session order and dates stay chronological for every start weekday (M3-02)",
        arguments: 0..<7
    )
    func schedulingIsChronologicalForEveryStartWeekday(startOffset: Int) throws {
        let calendar = Calendar.current
        let baseStart = Date(timeIntervalSince1970: 1_752_364_800)
        let startDate = try #require(calendar.date(byAdding: .day, value: startOffset, to: baseStart))
        let days: [Weekday] = [.monday, .wednesday, .friday]
        let input = PlanInput(
            goal: .generalFitness,
            experience: .notYet,
            regularity: nil,
            equipment: Set(EquipmentCatalog.all),
            injuries: [:],
            trainingDays: days,
            scheduleType: .scheduled,
            planLengthWeeks: 4,
            sessionDurationMinutes: 60,
            startDate: startDate
        )
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 21)

        let chosen = Set(days.map(\.rawValue))
        var previousDate: Date?
        for week in plan.weeks {
            #expect(week.sessions.count == 3)
            let weekStart = try #require(
                calendar.date(byAdding: .day, value: (week.number - 1) * 7, to: startDate)
            )
            let weekEnd = try #require(calendar.date(byAdding: .day, value: 7, to: weekStart))

            for session in week.sessions {
                let date = try #require(session.date)
                let weekday = try #require(session.weekday)

                #expect(chosen.contains(weekday.rawValue))
                #expect(calendar.component(.weekday, from: date) == weekday.rawValue)
                #expect(date >= calendar.startOfDay(for: weekStart))
                #expect(date < weekEnd)

                if let previousDate {
                    #expect(date > previousDate)
                }
                previousDate = date
            }

            #expect(week.sessions.map(\.indexInWeek) == Array(1...week.sessions.count))
            let weekDates = week.sessions.compactMap(\.date)
            #expect(weekDates == weekDates.sorted())
        }

        let orderIndexes = plan.weeks.flatMap { $0.sessions.map(\.orderIndex) }
        #expect(orderIndexes == Array(0..<orderIndexes.count))
    }

    @Test("A mid-week start begins with the first upcoming training day, not the sorted-first weekday")
    func midWeekStartBeginsWithFirstUpcomingTrainingDay() throws {
        let calendar = Calendar.current
        var start = Date(timeIntervalSince1970: 1_752_364_800)
        while calendar.component(.weekday, from: start) != Weekday.wednesday.rawValue {
            start = try #require(calendar.date(byAdding: .day, value: 1, to: start))
        }
        let input = PlanInput(
            goal: .generalFitness,
            experience: .notYet,
            regularity: nil,
            equipment: Set(EquipmentCatalog.all),
            injuries: [:],
            trainingDays: [.monday, .wednesday, .friday],
            scheduleType: .scheduled,
            planLengthWeeks: 2,
            sessionDurationMinutes: 60,
            startDate: start
        )
        let plan = try PlanEngine.generate(input: input, catalog: Self.makeCatalog(), seed: 3)

        let firstWeek = try #require(plan.weeks.first)
        #expect(firstWeek.sessions.map(\.weekday) == [.wednesday, .friday, .monday])
        let dates = firstWeek.sessions.compactMap(\.date)
        #expect(dates.count == 3)
        #expect(dates == dates.sorted())
        #expect(calendar.isDate(dates[0], inSameDayAs: start))
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
        #expect(first.weeks.flatMap(\.sessions).map(\.focus) == second.weeks.flatMap(\.sessions).map(\.focus))
    }

    @Test("Deterministic seed includes pain levels, not just injury areas")
    func deterministicSeedIncludesPainLevels() {
        let base = Self.makeInput(equipment: Set(EquipmentCatalog.all), injuries: [.shoulders: 2])
        let higher = Self.makeInput(equipment: Set(EquipmentCatalog.all), injuries: [.shoulders: 5])
        #expect(base.deterministicSeed != higher.deterministicSeed)
        #expect(base.deterministicSeed == base.deterministicSeed)
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
