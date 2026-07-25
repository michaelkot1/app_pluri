import Foundation

/// Canonical session-focus codes persisted on `plan_workouts.focus`
/// (SPEC §14 #46 / M3-18). Snake_case matches the Postgres CHECK list.
nonisolated enum SessionFocusCode: String, CaseIterable, Hashable, Sendable {
    case fullBodyA = "full_body_a"
    case fullBodyB = "full_body_b"
    case push
    case pull
    case legs
    case upper
    case lower
    case chestTriceps = "chest_triceps"
    case backBiceps = "back_biceps"
    case shouldersArms = "shoulders_arms"
    case accessories
}

/// A training day's job before exercise selection (SPEC §14 #46): primary /
/// secondary WorkoutX target muscles, a display title, and a design-token color.
///
/// Pure and portable — no SwiftUI — so the same values can later ship in the
/// `generate-plan` Edge Function (PLAN §1.3).
nonisolated struct SessionFocus: Hashable, Sendable {
    let code: SessionFocusCode
    let displayTitle: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let colorToken: WorkoutColorToken

    /// Whether this focus is a Full Body variant (earned only for 2-day splits
    /// or small-pool fallback — SPEC §14 #46).
    var isFullBody: Bool {
        code == .fullBodyA || code == .fullBodyB
    }

    // MARK: Catalog

    static let fullBodyA = SessionFocus(
        code: .fullBodyA,
        displayTitle: "Full Body A",
        primaryMuscles: ["Pectorals", "Quads", "Delts"],
        secondaryMuscles: ["Triceps", "Abs", "Calves"],
        colorToken: .accentPink
    )

    static let fullBodyB = SessionFocus(
        code: .fullBodyB,
        displayTitle: "Full Body B",
        primaryMuscles: ["Lats", "Hamstrings", "Glutes"],
        secondaryMuscles: ["Biceps", "Upper Back", "Abs"],
        colorToken: .accentLavender
    )

    static let push = SessionFocus(
        code: .push,
        displayTitle: "Push",
        primaryMuscles: ["Pectorals", "Delts", "Triceps"],
        secondaryMuscles: ["Abs", "Serratus Anterior"],
        colorToken: .brandOrange
    )

    static let pull = SessionFocus(
        code: .pull,
        displayTitle: "Pull",
        primaryMuscles: ["Lats", "Upper Back", "Biceps", "Traps"],
        secondaryMuscles: ["Delts", "Forearms"],
        colorToken: .statusBlue
    )

    static let legs = SessionFocus(
        code: .legs,
        displayTitle: "Legs",
        primaryMuscles: ["Quads", "Hamstrings", "Glutes", "Calves"],
        secondaryMuscles: ["Abs", "Abductors", "Adductors"],
        colorToken: .statusGreen
    )

    static let upper = SessionFocus(
        code: .upper,
        displayTitle: "Upper Body",
        primaryMuscles: ["Pectorals", "Lats", "Delts", "Biceps", "Triceps"],
        secondaryMuscles: ["Upper Back", "Abs"],
        colorToken: .brandOrangeDeep
    )

    static let lower = SessionFocus(
        code: .lower,
        displayTitle: "Lower Body",
        primaryMuscles: ["Quads", "Hamstrings", "Glutes", "Calves"],
        secondaryMuscles: ["Abs", "Abductors"],
        colorToken: .statusGreen
    )

    static let chestTriceps = SessionFocus(
        code: .chestTriceps,
        displayTitle: "Chest & Triceps",
        primaryMuscles: ["Pectorals", "Triceps"],
        secondaryMuscles: ["Delts", "Abs"],
        colorToken: .brandOrange
    )

    static let backBiceps = SessionFocus(
        code: .backBiceps,
        displayTitle: "Back & Biceps",
        primaryMuscles: ["Lats", "Upper Back", "Biceps"],
        secondaryMuscles: ["Traps", "Forearms"],
        colorToken: .statusBlue
    )

    static let shouldersArms = SessionFocus(
        code: .shouldersArms,
        displayTitle: "Shoulders & Arms",
        primaryMuscles: ["Delts", "Biceps", "Triceps"],
        secondaryMuscles: ["Traps", "Forearms"],
        colorToken: .brandCoralSoft
    )

    static let accessories = SessionFocus(
        code: .accessories,
        displayTitle: "Accessories",
        primaryMuscles: ["Abs", "Calves", "Forearms"],
        secondaryMuscles: ["Delts", "Biceps"],
        colorToken: .accentLavender
    )

    /// Every defined focus, in a stable order for tests and CHECK coverage.
    static let all: [SessionFocus] = [
        .fullBodyA, .fullBodyB, .push, .pull, .legs, .upper, .lower,
        .chestTriceps, .backBiceps, .shouldersArms, .accessories,
    ]

    static func focus(for code: SessionFocusCode) -> SessionFocus {
        all.first { $0.code == code } ?? .fullBodyA
    }

    // MARK: Weekly split (SPEC §14 #46)

    /// Derives the week's session focuses from days/week + experience/goal.
    /// Never asked in onboarding — reversible forks recorded in SPEC §14 #49.
    static func split(
        daysPerWeek: Int,
        experience: ExperienceLevel,
        goal: Goal
    ) -> [SessionFocus] {
        let days = min(max(daysPerWeek, 2), 6)
        switch days {
        case 2:
            return [.fullBodyA, .fullBodyB]
        case 3:
            return isBeginner(experience)
                ? [.upper, .lower, .fullBodyA]
                : [.push, .pull, .legs]
        case 4:
            return prefersBodyPartSplit(experience: experience, goal: goal)
                ? [.chestTriceps, .backBiceps, .legs, .shouldersArms]
                : [.push, .pull, .legs, .upper]
        case 5:
            return prefersBodyPartSplit(experience: experience, goal: goal)
                ? [.chestTriceps, .backBiceps, .legs, .shouldersArms, .accessories]
                : [.push, .pull, .legs, .push, .pull]
        default: // 6
            return prefersBodyPartSplit(experience: experience, goal: goal)
                ? [.chestTriceps, .backBiceps, .legs, .shouldersArms, .upper, .lower]
                : [.push, .pull, .legs, .push, .pull, .legs]
        }
    }

    /// Beginner fork: `Not yet` and `1–6 months` use Upper / Lower / Full Body
    /// on 3-day plans (SPEC §14 #49).
    static func isBeginner(_ experience: ExperienceLevel) -> Bool {
        switch experience {
        case .notYet, .oneToSixMonths: true
        case .sixToTwelveMonths, .oneToTwoYears, .twoPlusYears: false
        }
    }

    /// Body-part (vs PPL) fork for 4–6 day splits: advanced experience
    /// (`1–2 years`+) or hypertrophy goal (SPEC §14 #49).
    static func prefersBodyPartSplit(experience: ExperienceLevel, goal: Goal) -> Bool {
        if goal == .buildMuscle { return true }
        switch experience {
        case .oneToTwoYears, .twoPlusYears: return true
        case .notYet, .oneToSixMonths, .sixToTwelveMonths: return false
        }
    }
}
