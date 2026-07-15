import Testing
@testable import Pluri

// This suite compiles into the `PluriTests` unit-test target (added in M1-17,
// hosted on the app so `@testable import` can reach the app's internal types).
//
// `CalorieCalculator` (Features/Onboarding/Models/CalorieCalculator.swift)
// is written as a pure enum with static functions specifically so it needs no
// test-target scaffolding beyond importing the app module — these are ordinary
// Swift Testing `@Test` functions.

@Suite("CalorieCalculator")
struct CalorieCalculatorTests {
    @Test("Male BMR matches Mifflin-St Jeor (+5 offset)")
    func maleBMR() {
        // 30yo, 80kg, 180cm: 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
        let bmr = CalorieCalculator.basalMetabolicRate(weightKG: 80, heightCM: 180, age: 30, gender: .male)
        #expect(bmr == 1780)
    }

    @Test("Female BMR matches Mifflin-St Jeor (-161 offset)")
    func femaleBMR() {
        // 30yo, 60kg, 165cm: 10*60 + 6.25*165 - 5*30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25
        let bmr = CalorieCalculator.basalMetabolicRate(weightKG: 60, heightCM: 165, age: 30, gender: .female)
        #expect(bmr == 1320.25)
    }

    @Test("Other gender uses the average of the male/female offsets")
    func otherGenderBMR() {
        let base = 10 * 70.0 + 6.25 * 170.0 - 5 * 25.0
        let bmr = CalorieCalculator.basalMetabolicRate(weightKG: 70, heightCM: 170, age: 25, gender: .other)
        #expect(bmr == base - 78)
    }

    @Test(
        "Activity multiplier bands map training days to the right multiplier",
        arguments: [
            (0, 1.2), (1, 1.2),
            (2, 1.375), (3, 1.375),
            (4, 1.55), (5, 1.55),
            (6, 1.725), (7, 1.725),
        ]
    )
    func activityMultiplier(days: Int, expected: Double) {
        #expect(CalorieCalculator.activityMultiplier(trainingDaysPerWeek: days) == expected)
    }

    @Test("Maintenance calories combine BMR and activity multiplier, rounded")
    func maintenanceCalories() {
        let calories = CalorieCalculator.maintenanceCalories(
            weightKG: 80,
            heightCM: 180,
            age: 30,
            gender: .male,
            trainingDaysPerWeek: 4
        )
        // BMR 1780 * 1.55 = 2759.0
        #expect(calories == 2759)
    }

    @Test("Maintenance calories are always positive for plausible adult inputs")
    func maintenanceCaloriesArePositive() {
        for gender in Gender.allCases {
            let calories = CalorieCalculator.maintenanceCalories(
                weightKG: 50,
                heightCM: 150,
                age: 70,
                gender: gender,
                trainingDaysPerWeek: 0
            )
            #expect(calories > 0)
        }
    }
}
