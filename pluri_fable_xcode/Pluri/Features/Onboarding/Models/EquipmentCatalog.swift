import Foundation

/// Display grouping for Q6 equipment — editorial categories over the flat
/// WorkoutX list. IDs/strings stay identical to `all`; only presentation changes.
struct EquipmentCategory: Identifiable, Sendable, Hashable {
    let title: String
    let items: [String]

    var id: String { title }
}

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
    /// Grouped for the Q6 vertical list UI. Every item in `all` appears
    /// exactly once across these categories.
    static let categories: [EquipmentCategory] = [
        EquipmentCategory(
            title: "Bodyweight",
            items: [
                "Body Weight",
                "Body Weight (with Resistance Band)",
                "Weighted",
                "Assisted",
                "Assisted (towel)",
            ]
        ),
        EquipmentCategory(
            title: "Free weights",
            items: [
                "Barbell",
                "Ez Barbell",
                "Ez Barbell + Exercise Ball",
                "Olympic Barbell",
                "Trap Bar",
                "Dumbbell",
                "Dumbbell (used as Handles for Deeper Range)",
                "Dumbbell + Exercise Ball",
                "Dumbbell + Exercise Ball + Tennis Ball",
                "Kettlebell",
                "Medicine Ball",
                "Hammer",
            ]
        ),
        EquipmentCategory(
            title: "Machines",
            items: [
                "Cable",
                "Leverage Machine",
                "Smith Machine",
                "Sled Machine",
            ]
        ),
        EquipmentCategory(
            title: "Cardio",
            items: [
                "Elliptical Machine",
                "Skierg Machine",
                "Stationary Bike",
                "Stepmill Machine",
                "Upper Body Ergometer",
            ]
        ),
        EquipmentCategory(
            title: "Accessories",
            items: [
                "Band",
                "Resistance Band",
                "Bosu Ball",
                "Stability Ball",
                "Roller",
                "Wheel Roller",
                "Rope",
                "Tire",
            ]
        ),
    ]

    /// The full WorkoutX equipment list, SPEC §3.2 Q6.
    /// Flattened from `categories` so IDs stay in sync with the UI groups.
    static let all: [String] = categories.flatMap(\.items)

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
