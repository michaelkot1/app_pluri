import Foundation

/// All onboarding answers, held in memory only (M1-04 / SPEC §2 — nothing
/// persists remotely until account creation at the paywall milestone).
///
/// Height/weight are stored canonically in metric regardless of the
/// locale-aware units shown on Q11 (SPEC §3.2), so downstream consumers
/// (`CalorieCalculator`, the future `PlanEngine`) never need to know which
/// units the user entered in.
@MainActor
@Observable
final class OnboardingAnswers {
    // Name entry
    var name: String = ""

    // Q1
    var fitnessType: FitnessType = .workout

    // Q2–Q4
    var goal: Goal?
    var experience: ExperienceLevel?
    var regularity: RegularityLevel?

    // Q5–Q6
    var location: WorkoutLocation?
    var equipment: Set<String> = []

    // Q7 — area -> pain level (1...5)
    var injuries: [BodyArea: Int] = [:]

    // Q8–Q9
    var trainingDays: Set<Weekday> = [.monday, .wednesday, .friday]
    var scheduleType: ScheduleType = .scheduled
    var planLengthWeeks: Int = 6

    // Q10
    var sessionDuration: SessionDuration = .oneHour

    // Q11 (canonical metric)
    var age: Int?
    var gender: Gender?
    var heightCM: Double?
    var weightKG: Double?

    // Q12
    var allergies: Set<String> = []

    // Q13
    var startDateOption: StartDateOption = .today
    var customStartDate: Date = .now

    /// The concrete date the plan should start on, resolved from Q13.
    var resolvedStartDate: Date {
        let calendar = Calendar.current
        switch startDateOption {
        case .today: return calendar.startOfDay(for: .now)
        case .tomorrow: return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        case .custom: return calendar.startOfDay(for: customStartDate)
        }
    }

    /// `nil` until age/gender/height/weight are all filled in (Q11 must be
    /// complete before Q12 can compute a number).
    var maintenanceCalories: Int? {
        guard let age, let gender, let heightCM, let weightKG else { return nil }
        return CalorieCalculator.maintenanceCalories(
            weightKG: weightKG,
            heightCM: heightCM,
            age: age,
            gender: gender,
            trainingDaysPerWeek: trainingDays.count
        )
    }
}
