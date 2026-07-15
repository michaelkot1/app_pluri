import Foundation

/// Q6 equipment data — the WorkoutX equipment list (SPEC §3.2) plus the
/// Home Gym / Small Gym / Bodyweight auto-select subsets.
///
/// Decision (SPEC §14, resolving §15's open question): Commercial Gym
/// selects every item below. The other three locations pre-select a
/// hand-picked, sensible subset of equipment someone in that setting would
/// plausibly have; the user can freely add/remove on the Q6 screen
/// afterwards. Subsets were chosen editorially (WorkoutX doesn't tag
/// equipment by "typical setting"):
///
/// - **Home Gym**: a rack + free weights + a few compact extras — the kind
///   of equipment someone who invested in a home setup would own.
/// - **Small Gym**: a boutique/small commercial gym — free weights plus a
///   handful of common machines and cardio basics, but not the full
///   specialty-machine range of a big commercial gym.
/// - **Bodyweight**: no equipment at all, plus the handful of items that
///   are themselves just bodyweight-assist tools (bands, rollers).
enum EquipmentCatalog {
    /// The full WorkoutX equipment list, SPEC §3.2 Q6.
    static let all: [String] = [
        "Assisted",
        "Assisted (towel)",
        "Band",
        "Barbell",
        "Body Weight",
        "Body Weight (with Resistance Band)",
        "Bosu Ball",
        "Cable",
        "Dumbbell",
        "Dumbbell (used as Handles for Deeper Range)",
        "Dumbbell + Exercise Ball",
        "Dumbbell + Exercise Ball + Tennis Ball",
        "Elliptical Machine",
        "Ez Barbell",
        "Ez Barbell + Exercise Ball",
        "Hammer",
        "Kettlebell",
        "Leverage Machine",
        "Medicine Ball",
        "Olympic Barbell",
        "Resistance Band",
        "Roller",
        "Rope",
        "Skierg Machine",
        "Sled Machine",
        "Smith Machine",
        "Stability Ball",
        "Stationary Bike",
        "Stepmill Machine",
        "Tire",
        "Trap Bar",
        "Upper Body Ergometer",
        "Weighted",
        "Wheel Roller",
    ]

    private static let homeGym: Set<String> = [
        "Band", "Barbell", "Body Weight", "Body Weight (with Resistance Band)",
        "Bosu Ball", "Dumbbell", "Dumbbell (used as Handles for Deeper Range)",
        "Ez Barbell", "Kettlebell", "Medicine Ball", "Olympic Barbell",
        "Resistance Band", "Rope", "Stability Ball", "Trap Bar", "Weighted",
    ]

    private static let smallGym: Set<String> = [
        "Assisted", "Band", "Barbell", "Body Weight", "Cable", "Dumbbell",
        "Ez Barbell", "Kettlebell", "Leverage Machine", "Medicine Ball",
        "Olympic Barbell", "Resistance Band", "Smith Machine", "Stability Ball",
        "Stationary Bike", "Trap Bar", "Weighted",
    ]

    private static let bodyweight: Set<String> = [
        "Body Weight", "Body Weight (with Resistance Band)", "Band",
        "Resistance Band", "Roller", "Wheel Roller",
    ]

    /// The auto-select default for a given Q5 location. Commercial Gym gets
    /// every equipment item; the rest get their hand-picked subset above.
    static func defaultSelection(for location: WorkoutLocation) -> Set<String> {
        switch location {
        case .commercialGym: Set(all)
        case .homeGym: homeGym
        case .smallGym: smallGym
        case .bodyweight: bodyweight
        }
    }
}
