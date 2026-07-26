import Foundation

/// Snake_case CHECK codes for Postgres profile/plan columns (M2-13).
/// Translates UI `rawValue`s (display strings) into schema-safe codes.
nonisolated enum DatabaseCodeMappings {
    // MARK: - Goal (profiles.goal / plans.goal)

    /// App has 4 goals; DB CHECK allows 6. Canonical mapping documented in SPEC §14.
    static func goalCode(_ goal: Goal) -> String {
        switch goal {
        case .buildMuscle: "build_muscle"
        case .getStronger: "build_strength"
        case .loseFatToneUp: "get_lean"
        case .generalFitness: "overall_fitness"
        }
    }

    static func goal(from code: String) -> Goal? {
        switch code {
        case "build_muscle": .buildMuscle
        case "build_strength": .getStronger
        case "get_lean", "lose_weight": .loseFatToneUp
        case "overall_fitness", "get_in_shape": .generalFitness
        default: nil
        }
    }

    // MARK: - Experience

    static func experienceCode(_ level: ExperienceLevel) -> String {
        switch level {
        case .notYet: "not_yet"
        case .oneToSixMonths: "1_6_months"
        case .sixToTwelveMonths: "6_12_months"
        case .oneToTwoYears: "1_2_years"
        case .twoPlusYears: "2_plus_years"
        }
    }

    static func experience(from code: String) -> ExperienceLevel? {
        switch code {
        case "not_yet": .notYet
        case "1_6_months": .oneToSixMonths
        case "6_12_months": .sixToTwelveMonths
        case "1_2_years": .oneToTwoYears
        case "2_plus_years": .twoPlusYears
        default: nil
        }
    }

    // MARK: - Regularity

    static func regularityCode(_ level: RegularityLevel) -> String {
        switch level {
        case .never: "never"
        case .onAndOff: "on_and_off"
        case .regularly: "regular"
        case .comingBack: "returning"
        }
    }

    static func regularity(from code: String) -> RegularityLevel? {
        switch code {
        case "never": .never
        case "on_and_off": .onAndOff
        case "regular": .regularly
        case "returning": .comingBack
        default: nil
        }
    }

    // MARK: - Location

    static func locationCode(_ location: WorkoutLocation) -> String {
        switch location {
        case .commercialGym: "commercial_gym"
        case .homeGym: "home_gym"
        case .smallGym: "small_gym"
        case .bodyweight: "bodyweight"
        }
    }

    static func location(from code: String) -> WorkoutLocation? {
        switch code {
        case "commercial_gym": .commercialGym
        case "home_gym": .homeGym
        case "small_gym": .smallGym
        case "bodyweight": .bodyweight
        default: nil
        }
    }

    // MARK: - Schedule

    static func scheduleTypeCode(_ type: ScheduleType) -> String {
        switch type {
        case .scheduled: "scheduled"
        case .flexible: "flexible"
        }
    }

    static func scheduleType(from code: String) -> ScheduleType? {
        switch code {
        case "scheduled": .scheduled
        case "flexible": .flexible
        default: nil
        }
    }

    // MARK: - Gender

    static func genderCode(_ gender: Gender) -> String {
        switch gender {
        case .male: "male"
        case .female: "female"
        case .other: "other"
        }
    }

    static func gender(from code: String) -> Gender? {
        switch code {
        case "male": .male
        case "female": .female
        case "other", "prefer_not_to_say": .other
        default: nil
        }
    }

    // MARK: - Weekday

    static func weekdayCode(_ day: Weekday) -> String {
        switch day {
        case .monday: "mon"
        case .tuesday: "tue"
        case .wednesday: "wed"
        case .thursday: "thu"
        case .friday: "fri"
        case .saturday: "sat"
        case .sunday: "sun"
        }
    }

    static func weekday(from code: String) -> Weekday? {
        switch code {
        case "mon": .monday
        case "tue": .tuesday
        case "wed": .wednesday
        case "thu": .thursday
        case "fri": .friday
        case "sat": .saturday
        case "sun": .sunday
        default: nil
        }
    }

    // MARK: - Dates

    private static let isoDate = Date.ISO8601FormatStyle()
        .year()
        .month()
        .day()
        .dateSeparator(.dash)

    static func dateString(_ date: Date) -> String {
        date.formatted(isoDate)
    }

    static func date(from string: String) -> Date? {
        try? Date(string, strategy: isoDate)
    }

    /// ISO-8601 timestamptz string for `workout_sessions` / `set_logs` (M4-03).
    static func timestampString(_ date: Date) -> String {
        date.formatted(.iso8601)
    }
}
