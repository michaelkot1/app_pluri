import Foundation

/// Pure, `nonisolated` maintenance-calorie math for Q12 (SPEC §3.2, §14
/// decision #5). Kept free of `@Observable`/`@MainActor` so it is trivially
/// unit-testable without a `ModelContext` or the main actor — see the report
/// for M1-14 on why no test target exists yet in this project.
enum CalorieCalculator {
    /// Mifflin-St Jeor basal metabolic rate.
    ///
    /// The formula is only defined for male/female; `.other` uses the
    /// average of the two sex-specific offsets (+5 and −161 → −78) as a
    /// reasonable, documented middle ground (SPEC §14).
    static func basalMetabolicRate(weightKG: Double, heightCM: Double, age: Int, gender: Gender) -> Double {
        let base = 10 * weightKG + 6.25 * heightCM - 5 * Double(age)
        switch gender {
        case .male: return base + 5
        case .female: return base - 161
        case .other: return base - 78
        }
    }

    /// Standard activity-multiplier bands (sedentary → very active), mapped
    /// from the user's chosen weekly training-day count (PLAN §1.4).
    static func activityMultiplier(trainingDaysPerWeek: Int) -> Double {
        switch trainingDaysPerWeek {
        case ..<2: 1.2
        case 2...3: 1.375
        case 4...5: 1.55
        default: 1.725
        }
    }

    /// Estimated daily maintenance calories: BMR × activity multiplier,
    /// rounded to the nearest whole calorie.
    static func maintenanceCalories(
        weightKG: Double,
        heightCM: Double,
        age: Int,
        gender: Gender,
        trainingDaysPerWeek: Int
    ) -> Int {
        let bmr = basalMetabolicRate(weightKG: weightKG, heightCM: heightCM, age: age, gender: gender)
        let multiplier = activityMultiplier(trainingDaysPerWeek: trainingDaysPerWeek)
        return Int((bmr * multiplier).rounded())
    }
}
