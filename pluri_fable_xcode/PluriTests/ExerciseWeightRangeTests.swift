import Foundation
import Testing
@testable import Pluri

@Suite("ExerciseWeightRange")
struct ExerciseWeightRangeTests {

    @Test("Barbell lower uses kg and lb ladders from research")
    func barbellLowerLadders() {
        let kg = ExerciseWeightRange.resolve(
            equipment: "Barbell",
            targetMuscle: "Quads",
            name: "Barbell Back Squat",
            usesImperial: false
        )
        #expect(kg.category == .barbellLower)
        #expect(kg.min == 10)
        #expect(kg.max == 300)
        #expect(kg.step == 2.5)
        #expect(kg.defaultValue == 20)

        let lb = ExerciseWeightRange.resolve(
            equipment: "Barbell",
            targetMuscle: "Quads",
            name: "Barbell Back Squat",
            usesImperial: true
        )
        #expect(lb.category == .barbellLower)
        #expect(lb.min == 25)
        #expect(lb.max == 700)
        #expect(lb.step == 5)
        #expect(lb.defaultValue == 45)
    }

    @Test("Dumbbell shoulder press is heavy, not light")
    func dumbbellShoulderPressIsHeavy() {
        let category = ExerciseWeightRange.classify(
            equipment: "Dumbbell",
            targetMuscle: "Shoulders",
            name: "Dumbbell Shoulder Press"
        )
        #expect(category == .dumbbellHeavy)
    }

    @Test("Dumbbell lateral raise is light")
    func dumbbellLateralRaiseIsLight() {
        let category = ExerciseWeightRange.classify(
            equipment: "Dumbbell",
            targetMuscle: "Shoulders",
            name: "Dumbbell Lateral Raise"
        )
        #expect(category == .dumbbellLight)
    }

    @Test("Assisted pull-up machine is machineCable, not addedLoad")
    func assistedPullUpIsMachine() {
        let category = ExerciseWeightRange.classify(
            equipment: "Assisted",
            targetMuscle: "Lats",
            name: "Assisted Pull-up"
        )
        #expect(category == .machineCable)
    }

    @Test("Body Weight equipment uses noLoad / duration logging")
    func bodyWeightNoLoad() {
        let category = ExerciseWeightRange.classify(
            equipment: "Body Weight",
            targetMuscle: "Pectorals",
            name: "Push-up"
        )
        #expect(category == .noLoad)
        #expect(
            ExerciseWeightRange.usesDurationLogging(
                equipment: "Body Weight",
                targetMuscle: "Pectorals",
                name: "Push-up"
            )
        )
    }

    @Test("Catalog equipment strings resolve expected categories")
    func catalogEquipmentStrings() {
        #expect(
            ExerciseWeightRange.classify(
                equipment: "Cable",
                targetMuscle: "Lats",
                name: "Lat Pulldown"
            ) == .machineCable
        )
        #expect(
            ExerciseWeightRange.classify(
                equipment: "Kettlebell",
                targetMuscle: "Shoulders",
                name: "Kettlebell Swing"
            ) == .kettlebell
        )
        #expect(
            ExerciseWeightRange.classify(
                equipment: "Leverage Machine",
                targetMuscle: "Quads",
                name: "Leg Press"
            ) == .legPressHeavy
        )
        #expect(
            ExerciseWeightRange.classify(
                equipment: "Smith Machine",
                targetMuscle: "Pectorals",
                name: "Smith Bench Press"
            ) == .barbellPress
        )
        #expect(
            ExerciseWeightRange.classify(
                equipment: "Trap Bar",
                targetMuscle: "Upper Legs",
                name: "Trap Bar Deadlift"
            ) == .barbellLower
        )
        #expect(
            ExerciseWeightRange.classify(
                equipment: "Resistance Band",
                targetMuscle: "Shoulders",
                name: "Band Pull-apart"
            ) == .noLoad
        )
    }

    @Test("Snapping and seeding prefer last logged weight")
    func snapAndSeed() {
        let range = ExerciseWeightRange.ladder(for: .barbellPress, unit: .kilogram)
        let seeded = range.seeded(withLastLoggedDisplay: 47.5)
        #expect(seeded == 47.5)

        #expect(range.snapped(61) == 60)

        let defaultSeed = range.seeded(withLastLoggedDisplay: nil)
        #expect(defaultSeed == 20)
    }

    @Test("Fallback and machine ladders cover both units")
    func fallbackAndMachineLadders() {
        let fallbackKg = ExerciseWeightRange.ladder(for: .fallback, unit: .kilogram)
        #expect(fallbackKg.min == 0)
        #expect(fallbackKg.max == 200)
        #expect(fallbackKg.step == 2.5)
        #expect(fallbackKg.defaultValue == 10)

        let machineLb = ExerciseWeightRange.ladder(for: .machineCable, unit: .pound)
        #expect(machineLb.min == 5)
        #expect(machineLb.max == 350)
        #expect(machineLb.step == 5)
        #expect(machineLb.defaultValue == 50)
    }

    @Test("Weighted pull-up on bodyweight equipment is addedLoad")
    func weightedPullUpAddedLoad() {
        let category = ExerciseWeightRange.classify(
            equipment: "Body Weight",
            targetMuscle: "Lats",
            name: "Weighted Pull-up"
        )
        #expect(category == .addedLoad)
    }
}
