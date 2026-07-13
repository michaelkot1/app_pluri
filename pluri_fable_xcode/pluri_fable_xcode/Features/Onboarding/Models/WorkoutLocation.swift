import Foundation

/// Q5 — "Where do you work out?" (SPEC §3.2). Drives the Q6 equipment
/// auto-select mapping — see `EquipmentCatalog.defaultSelection(for:)`.
enum WorkoutLocation: String, CaseIterable, Identifiable, Sendable {
    case commercialGym = "Commercial Gym"
    case homeGym = "Home Gym"
    case smallGym = "Small Gym"
    case bodyweight = "Bodyweight"

    var id: Self { self }
    var title: String { rawValue }
}
