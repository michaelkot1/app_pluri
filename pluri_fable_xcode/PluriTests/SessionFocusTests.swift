import Foundation
import Testing
@testable import Pluri

@Suite("SessionFocus")
struct SessionFocusTests {

    // MARK: Split length

    @Test(
        "Split length matches days per week",
        arguments: [2, 3, 4, 5, 6]
    )
    func splitLengthMatchesDays(days: Int) {
        let split = SessionFocus.split(
            daysPerWeek: days,
            experience: .oneToTwoYears,
            goal: .generalFitness
        )
        #expect(split.count == days)
    }

    @Test("Days outside 2–6 clamp to the legal range")
    func daysClampToLegalRange() {
        #expect(
            SessionFocus.split(daysPerWeek: 1, experience: .notYet, goal: .generalFitness).count == 2
        )
        #expect(
            SessionFocus.split(daysPerWeek: 9, experience: .twoPlusYears, goal: .buildMuscle).count == 6
        )
    }

    // MARK: Beginner vs advanced fork (3-day)

    @Test("Beginners on 3 days get Upper / Lower / Full Body")
    func beginnerThreeDaySplit() {
        for experience: ExperienceLevel in [.notYet, .oneToSixMonths] {
            let codes = SessionFocus.split(
                daysPerWeek: 3,
                experience: experience,
                goal: .generalFitness
            ).map(\.code)
            #expect(codes == [.upper, .lower, .fullBodyA])
        }
    }

    @Test("Non-beginners on 3 days get Push / Pull / Legs")
    func advancedThreeDaySplit() {
        for experience: ExperienceLevel in [.sixToTwelveMonths, .oneToTwoYears, .twoPlusYears] {
            let codes = SessionFocus.split(
                daysPerWeek: 3,
                experience: experience,
                goal: .generalFitness
            ).map(\.code)
            #expect(codes == [.push, .pull, .legs])
        }
    }

    // MARK: 2-day / 4–6 forks

    @Test("Two-day split is Full Body A / B with differing primaries")
    func twoDayFullBodyPatternsDiffer() {
        let split = SessionFocus.split(
            daysPerWeek: 2,
            experience: .notYet,
            goal: .generalFitness
        )
        #expect(split.map(\.code) == [.fullBodyA, .fullBodyB])
        #expect(Set(split[0].primaryMuscles).isDisjoint(with: Set(split[1].primaryMuscles)))
    }

    @Test("Hypertrophy / advanced 4-day prefers body-part split")
    func fourDayBodyPartFork() {
        let bodyPart = SessionFocus.split(
            daysPerWeek: 4,
            experience: .twoPlusYears,
            goal: .buildMuscle
        ).map(\.code)
        #expect(bodyPart == [.chestTriceps, .backBiceps, .legs, .shouldersArms])

        let ppl = SessionFocus.split(
            daysPerWeek: 4,
            experience: .notYet,
            goal: .generalFitness
        ).map(\.code)
        #expect(ppl == [.push, .pull, .legs, .upper])
    }

    // MARK: Catalog coverage

    @Test("Every SessionFocusCode has a catalog entry")
    func allFocusCodesCovered() {
        let catalogCodes = Set(SessionFocus.all.map(\.code))
        #expect(catalogCodes == Set(SessionFocusCode.allCases))
    }

    @Test("Every focus uses WorkoutX targetList muscle names")
    func primaryMusclesAreWorkoutXTargets() {
        let allowed = Set([
            "Abductors", "Abs", "Adductors", "Biceps", "Calves",
            "Cardiovascular System", "Delts", "Forearms", "Glutes",
            "Hamstrings", "Lats", "Levator Scapulae", "Pectorals",
            "Quads", "Serratus Anterior", "Spine", "Traps", "Triceps",
            "Upper Back",
        ])
        for focus in SessionFocus.all {
            #expect(!focus.primaryMuscles.isEmpty)
            #expect(Set(focus.primaryMuscles).isSubset(of: allowed))
            #expect(Set(focus.secondaryMuscles).isSubset(of: allowed))
            #expect(!focus.displayTitle.isEmpty)
        }
    }

    @Test("Every BodyArea maps to at least one WorkoutX target muscle")
    func everyBodyAreaMapped() {
        for area in BodyArea.allCases {
            let muscles = BodyAreaMuscleMapping.targetMuscles(for: area)
            #expect(!muscles.isEmpty)
        }
    }

    @Test("BodyArea mappings only use WorkoutX targetList names")
    func bodyAreaMusclesAreWorkoutXTargets() {
        let allowed = Set([
            "Abductors", "Abs", "Adductors", "Biceps", "Calves",
            "Cardiovascular System", "Delts", "Forearms", "Glutes",
            "Hamstrings", "Lats", "Levator Scapulae", "Pectorals",
            "Quads", "Serratus Anterior", "Spine", "Traps", "Triceps",
            "Upper Back",
        ])
        for area in BodyArea.allCases {
            #expect(BodyAreaMuscleMapping.targetMuscles(for: area).isSubset(of: allowed))
        }
    }

    @Test("Pain lookup returns the highest implicated pain level")
    func painLevelLookup() {
        let injuries: [BodyArea: Int] = [.shoulders: 2, .chest: 5]
        #expect(BodyAreaMuscleMapping.painLevel(for: "Delts", injuries: injuries) == 2)
        #expect(BodyAreaMuscleMapping.painLevel(for: "Pectorals", injuries: injuries) == 5)
        #expect(BodyAreaMuscleMapping.painLevel(for: "Quads", injuries: injuries) == nil)
    }
}
